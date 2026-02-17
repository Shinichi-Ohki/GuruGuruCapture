// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GuruGuruCapture",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GuruGuruCapture",
            path: "Sources"
        )
    ]
)
