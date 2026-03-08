// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SalesDebriefCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SalesDebriefCore",
            targets: ["SalesDebriefCore"]
        ),
    ],
    targets: [
        .target(
            name: "SalesDebriefCore"
        ),
        .testTarget(
            name: "SalesDebriefCoreTests",
            dependencies: ["SalesDebriefCore"]
        ),
    ]
)
