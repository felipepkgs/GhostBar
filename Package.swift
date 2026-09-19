// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TouchBarVisualizer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TouchBarVisualizer",
            resources: [.copy("Resources/overlay")]
        )
    ]
)
