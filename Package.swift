// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "distributed-lock-valkey",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(name: "DistributedLockValkey", targets: ["DistributedLockValkey"])
  ],
  dependencies: [
    .package(url: "https://github.com/swift-server/RediStack.git", from: "1.0.0"),
    .package(url: "https://github.com/rosecoder/distributed-lock-swift.git", from: "0.0.3"),
  ],
  targets: [
    .target(
      name: "DistributedLockValkey",
      dependencies: [
        .product(name: "DistributedLock", package: "distributed-lock-swift"),
        .product(name: "RediStack", package: "RediStack"),
      ]
    ),
    .testTarget(
      name: "DistributedLockValkeyTests",
      dependencies: ["DistributedLockValkey"]
    ),
  ]
)
