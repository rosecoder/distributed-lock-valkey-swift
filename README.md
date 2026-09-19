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

## Lock timeout

A lock key expires on its own so a crashed holder cannot block the resource forever. The timeout is
per lock, since it belongs to the critical section rather than to the client, and defaults to 30
seconds:

```swift
try await lock.withLock("a-long-running-job", timeout: .seconds(600)) {
  // operations that should be protected by the lock
}
```

Pick a timeout above the longest critical section you expect. An operation that runs longer than the
timeout loses its lock while still running, and another holder can then acquire it concurrently —
`unlock` detects this, logs an error, and leaves the key alone rather than releasing a lock it no
longer owns.

Valkey expires keys at whole-second granularity, so the timeout must be at least one second and any
sub-second part of it is truncated.
