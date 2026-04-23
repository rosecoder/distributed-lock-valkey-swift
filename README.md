# Distributed Lock for Valkey in Swift

This package provides a Swift implementation for distributed locking against [Valkey](https://valkey.io) (or any Redis-compatible server) using [valkey-swift](https://github.com/valkey-io/valkey-swift). It is built to be used with [distributed-lock-swift](https://github.com/rosecoder/distributed-lock-swift).

`ValkeyClient` needs a background task to run the connection pool; in a long-lived process you can keep that task for the app lifetime, or use [swift-service-lifecycle](https://github.com/swift-server/swift-service-lifecycle) as described in the valkey-swift README.

## Example usage

```swift
import DistributedLockValkey
import Logging
import Valkey

let logger = Logger(label: "my-app")
let client = ValkeyClient(
  .hostname("127.0.0.1", port: 6379),
  logger: logger
)
async let _ = client.run()

let lock = ValkeyLock(client: client)

try await lock.withLock("my-resource") {
  // operations that should be protected by the lock
}
```

It also provides logging and tracing support for the time the lock is waiting to be acquired.
