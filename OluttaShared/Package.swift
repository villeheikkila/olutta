// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OluttaShared",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17)],
    products: [
        .library(
            name: "OluttaShared",
            targets: ["OluttaShared"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.12.2"),
    ],
    targets: [
        .target(
            name: "OluttaShared", dependencies: [.product(name: "HTTPTypes", package: "swift-http-types"), .product(name: "Crypto", package: "swift-crypto")],
        ),
        .testTarget(
            name: "OluttaSharedTests",
            dependencies: ["OluttaShared"],
        ),
    ],
)
