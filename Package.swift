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
    .package(url: "https://github.com/valkey-io/valkey-swift", from: "1.0.0"),
    .package(url: "https://github.com/rosecoder/distributed-lock-swift.git", from: "0.1.0"),
  ],
  targets: [
    .target(
      name: "DistributedLockValkey",
      dependencies: [
        .product(name: "DistributedLock", package: "distributed-lock-swift"),
        .product(name: "Valkey", package: "valkey-swift"),
      ]
    ),
    .testTarget(
      name: "DistributedLockValkeyTests",
      dependencies: [
        "DistributedLockValkey",
        .product(name: "Valkey", package: "valkey-swift"),
      ]
    ),
  ]
)
