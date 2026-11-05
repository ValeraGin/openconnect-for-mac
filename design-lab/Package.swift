// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DesignLab",
    platforms: [.macOS("14.4")],
    dependencies: [.package(url: "https://github.com/sindresorhus/Settings.git", exact: "3.0.0")],
    targets: [
        .executableTarget(name: "DesignLab", dependencies: [.product(name: "Settings", package: "Settings")])
    ]
)
