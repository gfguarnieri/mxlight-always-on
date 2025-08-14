// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MenuBarApp",
    platforms: [.macOS(.v12)],
    products: [
        .executable(
            name: "MenuBarApp",
            targets: ["MenuBarApp"]
        ),
    ],
    dependencies: [
        // 依赖项，如果需要的话
    ],
    targets: [
        .executableTarget(
            name: "MenuBarApp",
            dependencies: [],
            path: "."
        ),
    ]
)