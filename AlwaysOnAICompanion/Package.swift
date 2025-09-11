// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AlwaysOnAICompanion",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "RecorderDaemon",
            targets: ["RecorderDaemon"]
        ),
        .executable(
            name: "MenuBarApp",
            targets: ["MenuBarApp"]
        ),
        .executable(
            name: "ScreenCaptureDemo",
            targets: ["Demo"]
        ),
        .executable(
            name: "LaunchAgentInstaller",
            targets: ["LaunchAgentInstaller"]
        ),
    ],
    dependencies: [
        // Add any external dependencies here if needed
    ],
    targets: [
        .executableTarget(
            name: "RecorderDaemon",
            dependencies: ["Shared"],
            path: "Sources/RecorderDaemon"
        ),
        .executableTarget(
            name: "MenuBarApp",
            dependencies: ["Shared"],
            path: "Sources/MenuBarApp"
        ),
        .executableTarget(
            name: "Demo",
            dependencies: ["Shared"],
            path: "Sources/Demo"
        ),
        .executableTarget(
            name: "LaunchAgentInstaller",
            dependencies: ["Shared"],
            path: "Sources/LaunchAgentInstaller"
        ),
        .target(
            name: "Shared",
            dependencies: [],
            path: "Sources/Shared"
        ),
        .testTarget(
            name: "AlwaysOnAICompanionTests",
            dependencies: ["Shared"],
            path: "Tests"
        ),
    ]
)