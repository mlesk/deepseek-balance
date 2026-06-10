// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeepseekBalance",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DeepseekBalance",
            dependencies: [],
            path: "Sources/DeepseekBalance",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
