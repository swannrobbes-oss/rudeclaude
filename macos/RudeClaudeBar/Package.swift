// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "RudeClaudeBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "RudeClaudeBar"),
    ]
)
