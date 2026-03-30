// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusCore",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "FocusCore",
            targets: ["FocusCore"]
        ),
    ],
    targets: [
        .target(
            name: "FocusCore",
            dependencies: [],
            path: "Sources/FocusCore"
        ),
        .testTarget(
            name: "FocusCoreTests",
            dependencies: ["FocusCore"],
            path: "Tests/FocusCoreTests"
        ),
    ]
)
