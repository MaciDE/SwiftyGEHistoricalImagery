// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyGEHistoricalImagery",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "SwiftyGEHistoricalImagery",
            targets: ["SwiftyGEHistoricalImagery"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.6.0"),
    ],
    targets: [
        .target(
            name: "SwiftyGEHistoricalImagery",
            dependencies: [.product(name: "SwiftProtobuf", package: "swift-protobuf")]),
        .testTarget(
            name: "SwiftyGEHistoricalImageryTests",
            dependencies: ["SwiftyGEHistoricalImagery"],
            path: "Tests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
