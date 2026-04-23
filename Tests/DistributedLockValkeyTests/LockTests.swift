import DistributedLock
import DistributedLockValkey
import Foundation
import NIO
@preconcurrency import RediStack
import Testing

@Suite struct LockTests {

  @Test func shouldLockAndUnlock() async throws {
    let host = ProcessInfo.processInfo.environment["REDIS_HOST"] ?? "127.0.0.1"
    let port = ProcessInfo.processInfo.environment["REDIS_PORT"].flatMap { Int($0) } ?? 6379

    let client = RedisConnectionPool(
      configuration: .init(
        initialServerConnectionAddresses: [try .makeAddressResolvingHost(host, port: port)],
        maximumConnectionCount: .maximumActiveConnections(1),
        connectionFactoryConfiguration: .init()
      ),
      boundEventLoop: MultiThreadedEventLoopGroup.singletonMultiThreadedEventLoopGroup.next()
    )

    let lock = RedisLock(client: client)

    #expect(try await client.get("lock/a").get().string?.isEmpty != false)

    try await lock.withLock("a") {
      Task {
        #expect(try await client.get("lock/a").get().string?.isEmpty == false)
        try await lock.withLock("a") {
          try await Task.sleep(for: .milliseconds(100))
        }
      }

      try await Task.sleep(for: .milliseconds(100))
    }
  }
}
