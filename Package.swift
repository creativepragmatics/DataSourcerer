// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "DataSourcerer",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "DataSourcerer",
            targets: ["DataSourcerer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "6.5.0"),
        .package(url: "https://github.com/krzysztofzablocki/Difference.git", from: "0.6.0")
    ],
    targets: [
        .target(
            name: "DataSourcerer",
            dependencies: [
                "ReactiveSwift"
            ]),
        .testTarget(
            name: "DataSourcererTests",
            dependencies: ["DataSourcerer", "Difference"]),
    ]
)
