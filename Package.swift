// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "DataSourcerer",
    platforms: [.iOS(.v10)], 
    products: [
        .library(
            name: "DataSourcerer",
            targets: ["DataSourcerer"]),
        .library(
            name: "DataSourcererUI",
            targets: ["DataSourcererUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "6.5.0"),
        .package(url: "https://github.com/krzysztofzablocki/Difference.git", from: "0.6.0"),
        .package(url: "https://github.com/ra1028/DifferenceKit.git", from: "1.1.5")
    ],
    targets: [
        .target(
            name: "DataSourcerer",
            dependencies: [
                "ReactiveSwift"
            ]
        ),
        .target(
            name: "DataSourcererUI",
            dependencies: [
                "DataSourcerer",
                "DifferenceKit",
                "MulticastDelegate"
            ]
        ),
        .target(name: "MulticastDelegate", dependencies: []),
        .testTarget(
            name: "DataSourcererTests",
            dependencies: ["DataSourcerer", "Difference"]
        ),
        .testTarget(
            name: "DataSourcererUITests",
            dependencies: ["DataSourcererUI", "MulticastDelegate", "Difference"]
        )
    ]
)
