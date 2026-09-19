import DistributedLock
import Logging
import Valkey

public final class ValkeyLock: DistributedLock {

  let client: ValkeyClient

  public init(client: ValkeyClient) {
    self.client = client
  }

  private let retryAttempts: UInt8 = 50
  private let minimumRetryDelayNanoseconds: UInt64 = 50_000_000  // 50 ms
  private let maximumRetryDelayNanoseconds: UInt64 = 500_000_000  // 500 ms

  public enum LockError: Error {
    case waitTimeout
  }

  public func lock(key: Key, timeout: Duration, logger: Logger) async throws {
    let value: String = String(Int.random(in: Int.min..<Int.max))
    try await setLock(key: key, value: value, timeout: timeout, logger: logger)
  }

  private func setLock(
    key: Key,
    value: String,
    timeout: Duration,
    tryCount: UInt8 = 0,
    logger: Logger
  ) async throws {
    // SET with NX and EX: success is non-nil "OK" reply; nil means key already exists.
    let result = try await client.set(
      valkeyKey(key),
      value: value,
      condition: .nx,
      expiration: .seconds(Self.expirationSeconds(for: timeout))
    )
    if result != nil {
      return
    }

    guard tryCount != retryAttempts else {
      throw LockError.waitTimeout
    }

    let waitDuration = (minimumRetryDelayNanoseconds..<maximumRetryDelayNanoseconds)
      .randomElement()!

    logger.debug("Lock \(key) is locked. Retry in \(waitDuration)ns.")
    try await Task.sleep(nanoseconds: waitDuration)

    try await setLock(
      key: key,
      value: value,
      timeout: timeout,
      tryCount: tryCount + 1,
      logger: logger
    )
  }

  public func unlock(
    key: Key,
    startedAt: ContinuousClock.Instant,
    timeout: Duration,
    logger: Logger
  ) async throws {
    let endedAt = ContinuousClock.Instant.now
    let duration = endedAt - startedAt
    // The key has already expired and may now belong to another holder, so deleting it would
    // release a lock we no longer own.
    guard duration < .seconds(Self.expirationSeconds(for: timeout)) else {
      logger.error(
        "Lock execution took longer than the \(timeout) timeout, so the lock expired while held: \(key)"
      )
      return
    }
    _ = try await client.del(keys: [valkeyKey(key)])
  }

  /// Valkey expires keys at whole-second granularity, so the timeout cannot be finer than that.
  private static func expirationSeconds(for timeout: Duration) -> Int {
    precondition(
      timeout >= .seconds(1),
      "A lock timeout must be at least one second, got \(timeout)."
    )
    return Int(timeout.components.seconds)
  }

  private func valkeyKey(_ key: Key) -> ValkeyKey {
    ValkeyKey("lock/" + key.rawValue)
  }
}
