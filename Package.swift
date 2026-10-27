// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "Grizzly",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Grizzly",
            path: "Sources/Grizzly"
        )
    ]
)
