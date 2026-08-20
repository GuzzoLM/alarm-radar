// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AlarmRadar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "alarm-radar", targets: ["AlarmRadar"]),
    ],
    targets: [
        .executableTarget(
            name: "AlarmRadar",
            path: "Sources/AlarmRadar"
        ),
        .testTarget(
            name: "AlarmRadarTests",
            dependencies: ["AlarmRadar"],
            path: "Tests/AlarmRadarTests"
        ),
    ]
)
