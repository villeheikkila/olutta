// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ylahylly",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17)],
    products: [
        .executable(name: "Ylahylly", targets: ["Ylahylly"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.8.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.23.0"),
        .package(url: "https://github.com/villeheikkila/swift-log-telegram", from: "0.0.1"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),
        .package(url: "https://github.com/villeheikkila/pgmq-swift", .upToNextMajor(from: "0.0.8")),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.24.2"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-redis.git", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Ylahylly",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "SwiftLogTelegram", package: "swift-log-telegram"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "PGMQ", package: "pgmq-swift"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "HummingbirdRedis", package: "hummingbird-redis"),
            ],
            path: "Sources",
            resources: [
                .copy("App/migrations.sql"),
            ]
        ),
        .testTarget(
            name: "YlahyllyTests",
            dependencies: [
                "Ylahylly",
            ],
            path: "Tests",
            resources: [
                .copy("Resources"),
            ]
        ),
    ]
)
