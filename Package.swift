// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Gitizen",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "Gitizen"),
        .testTarget(name: "GitizenTests", dependencies: ["Gitizen"]),
    ]
)
