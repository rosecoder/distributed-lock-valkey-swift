import DistributedLock
import DistributedLockValkey
import Foundation
import Logging
import Testing
import Valkey

@Suite struct LockTests {

  @Test func shouldLockAndUnlock() async throws {
    let host = ProcessInfo.processInfo.environment["REDIS_HOST"] ?? "127.0.0.1"
    let port = ProcessInfo.processInfo.environment["REDIS_PORT"].flatMap { Int($0) } ?? 6379

    let logger = Logger(label: "DistributedLockValkeyTests")
    let client = ValkeyClient(
      .hostname(host, port: port),
      logger: logger
    )
    async let _ = client.run()

    let lock = ValkeyLock(client: client)

    let keyA = ValkeyKey("lock/a")
    _ = try await client.del(keys: [keyA])
    #expect(stringFromBulk(try await client.get(keyA))?.isEmpty != false)

    // Start a contending lock in the background; it cannot proceed until the outer withLock returns.
    let nested = try await lock.withLock("a") {
      let t = Task {
        #expect(stringFromBulk(try await client.get(keyA))?.isEmpty == false)
        try await lock.withLock("a") {
          try await Task.sleep(for: .milliseconds(100))
        }
      }
      try await Task.sleep(for: .milliseconds(100))
      return t
    }
    _ = try await nested.value
  }

  @Test func shouldExpireTheKeyAfterTheDefaultTimeout() async throws {
    let client = makeClient()
    async let _ = client.run()
    let lock = ValkeyLock(client: client)

    let key = ValkeyKey("lock/default-timeout")
    _ = try await client.del(keys: [key])

    try await lock.withLock("default-timeout") {
      let ttl = try await client.ttl(key)
      #expect(ttl == 30)
    }
  }

  @Test func shouldExpireTheKeyAfterTheGivenTimeout() async throws {
    let client = makeClient()
    async let _ = client.run()
    let lock = ValkeyLock(client: client)

    let key = ValkeyKey("lock/given-timeout")
    _ = try await client.del(keys: [key])

    try await lock.withLock("given-timeout", timeout: .seconds(600)) {
      let ttl = try await client.ttl(key)
      #expect(ttl == 600)
    }
  }

  /// The timeout belongs to the critical section, so the same lock can hold different ones at once.
  @Test func shouldUseADifferentTimeoutPerKey() async throws {
    let client = makeClient()
    async let _ = client.run()
    let lock = ValkeyLock(client: client)

    let shortKey = ValkeyKey("lock/short-timeout")
    let longKey = ValkeyKey("lock/long-timeout")
    _ = try await client.del(keys: [shortKey, longKey])

    try await lock.withLock("short-timeout", timeout: .seconds(5)) {
      try await lock.withLock("long-timeout", timeout: .seconds(600)) {
        let shortTTL = try await client.ttl(shortKey)
        let longTTL = try await client.ttl(longKey)
        #expect(shortTTL == 5)
        #expect(longTTL == 600)
      }
    }
  }

  @Test func shouldTruncateASubSecondPartOfTheTimeout() async throws {
    let client = makeClient()
    async let _ = client.run()
    let lock = ValkeyLock(client: client)

    let key = ValkeyKey("lock/truncated-timeout")
    _ = try await client.del(keys: [key])

    try await lock.withLock("truncated-timeout", timeout: .milliseconds(1500)) {
      let ttl = try await client.ttl(key)
      #expect(ttl == 1)
    }
  }
}

private func makeClient() -> ValkeyClient {
  let host = ProcessInfo.processInfo.environment["REDIS_HOST"] ?? "127.0.0.1"
  let port = ProcessInfo.processInfo.environment["REDIS_PORT"].flatMap { Int($0) } ?? 6379
  return ValkeyClient(
    .hostname(host, port: port),
    logger: Logger(label: "DistributedLockValkeyTests")
  )
}

/// Returns `nil` when the key is absent; otherwise a UTF-8 string from the bulk value.
private func stringFromBulk(_ value: RESPBulkString?) -> String? {
  value.map { bulk in
    String(decoding: bulk, as: UTF8.self)
  }
}
