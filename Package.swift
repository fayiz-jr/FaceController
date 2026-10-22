// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FaceController",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "FaceController", path: "Sources/FaceController")
    ]
)
