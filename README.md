# Distributed Lock for Valkey in Swift

This package provides a Swift implementation for distributed locking against [Valkey](https://valkey.io) (or any Redis-compatible server) using a Redis-protocol client. It is built to be used with [distributed-lock-swift](https://github.com/rosecoder/distributed-lock-swift) and [RediStack](https://github.com/swift-server/RediStack).

## Example usage

```swift
import DistributedLockValkey

let lock = RedisLock(client: redisClient)

try await lock.withLock("my-resource") {
    // operations that should be protected by the lock
}
```

It also provides logging and tracing support for the time the lock is waiting to be acquired.
