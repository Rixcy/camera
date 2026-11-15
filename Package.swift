// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Camera",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Camera", targets: ["Camera"]),
    ],
    targets: [
        .target(name: "CameraCore"),
        .executableTarget(name: "Camera", dependencies: ["CameraCore"]),
        .testTarget(name: "CameraCoreTests", dependencies: ["CameraCore"]),
    ]
)
