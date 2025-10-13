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
        // SwiftyTesseract dependency removed for mock implementation
        // In production, you would add: .package(url: "https://github.com/SwiftyTesseract/SwiftyTesseract.git", from: "4.0.0")
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3")
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
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources/Shared"
        ),
        .testTarget(
            name: "AlwaysOnAICompanionTests",
            dependencies: ["Shared"],
            path: "Tests"
        ),
    ]
)