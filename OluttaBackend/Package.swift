// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "OluttaBackend",
    platforms: [.macOS(.v14), .iOS(.v26)],
    products: [
        .executable(name: "OluttaBackend", targets: ["OluttaBackend"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.8.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.23.0"),
        .package(url: "https://github.com/villeheikkila/swift-log-telegram", from: "0.0.3"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2"),

        .package(url: "https://github.com/villeheikkila/pgmq-swift", .upToNextMajor(from: "0.0.8")),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.24.2"),
        .package(
            url: "https://github.com/hummingbird-project/hummingbird-redis.git", from: "2.0.0",
        ),
        .package(url: "https://github.com/MacPaw/OpenAI.git", exact: "0.4.1"),
        .package(name: "OluttaShared", path: "../OluttaShared"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-postgres.git", from: "0.5.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-auth.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server-community/APNSwift.git", from: "6.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "OluttaBackend",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdAuth", package: "hummingbird-auth"),
                .product(name: "SwiftLogTelegram", package: "swift-log-telegram"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "PGMQ", package: "pgmq-swift"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "HummingbirdRedis", package: "hummingbird-redis"),
                .product(name: "OpenAI", package: "OpenAI"),
                .product(name: "OluttaShared", package: "OluttaShared"),
                .product(name: "HummingbirdPostgres", package: "hummingbird-postgres"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "APNS", package: "apnswift"),
            ],
            path: "Sources",
        ),
    ],
)
