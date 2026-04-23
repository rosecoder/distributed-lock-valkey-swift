import DistributedLock
import Logging
@preconcurrency import RediStack

public final class RedisLock: DistributedLock {

  let client: RedisClient

  public init(client: RedisClient) {
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
    let wasSet = try await client.set(
      redisKey(key),
      to: value,
      onCondition: .keyDoesNotExist,
      expiration: .seconds(timeoutSeconds)
    ).get()
    if wasSet == .ok {
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
    _ = try await client.delete(redisKey(key)).get()
  }

  private func redisKey(_ key: Key) -> RedisKey {
    RedisKey("lock/" + key.rawValue)
  }
}
