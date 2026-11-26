// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Yokuro",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Yokuro", path: "Sources/Yokuro")
    ]
)
