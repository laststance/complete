// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Complete",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Complete",
            targets: ["Complete"]
        )
    ],
    dependencies: [
        // KeyboardShortcuts library for global hotkey registration (20-50ms response)
        // Research: docs/macos-global-hotkey-research-2024.md
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Complete",
            dependencies: ["KeyboardShortcuts"],
            path: "src"
        ),
        .testTarget(
            name: "CompleteTests",
            dependencies: ["Complete"],
            path: "tests"
        )
    ]
)
