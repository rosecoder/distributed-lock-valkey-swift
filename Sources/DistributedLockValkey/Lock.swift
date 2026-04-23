import DistributedLock
import Logging
import Valkey

public final class ValkeyLock: DistributedLock {

  let client: ValkeyClient

  public init(client: ValkeyClient) {
    self.client = client
  }

  private let retryAttempts: UInt8 = 50
  private let timeoutSeconds: Int = 30  // 30 sec
  private let minimumRetryDelayNanoseconds: UInt64 = 50_000_000  // 50 ms
  private let maximumRetryDelayNanoseconds: UInt64 = 500_000_000  // 500 ms

  public enum LockError: Error {
    case waitTimeout
  }

  public func lock(key: Key, logger: Logger) async throws {
    let value: String = String(Int.random(in: Int.min..<Int.max))
    try await setLock(key: key, value: value, logger: logger)
  }

  private func setLock(key: Key, value: String, tryCount: UInt8 = 0, logger: Logger)
    async throws
  {
    // SET with NX and EX: success is non-nil "OK" reply; nil means key already exists.
    let result = try await client.set(
      valkeyKey(key),
      value: value,
      condition: .nx,
      expiration: .seconds(timeoutSeconds)
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

    try await setLock(key: key, value: value, tryCount: tryCount + 1, logger: logger)
  }

  public func unlock(key: Key, startedAt: ContinuousClock.Instant, logger: Logger) async throws {
    let endedAt = ContinuousClock.Instant.now
    let duration = endedAt - startedAt
    guard duration.components.seconds < timeoutSeconds else {
      logger.error("Lock execution took longer than timeout: \(key)")
      return
    }
    _ = try await client.del(keys: [valkeyKey(key)])
  }

  private func valkeyKey(_ key: Key) -> ValkeyKey {
    ValkeyKey("lock/" + key.rawValue)
  }
}
