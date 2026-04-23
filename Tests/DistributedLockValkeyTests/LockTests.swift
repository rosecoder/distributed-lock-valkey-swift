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
}

/// Returns `nil` when the key is absent; otherwise a UTF-8 string from the bulk value.
private func stringFromBulk(_ value: RESPBulkString?) -> String? {
  value.map { bulk in
    String(decoding: bulk, as: UTF8.self)
  }
}
