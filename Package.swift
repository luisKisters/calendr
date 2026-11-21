// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Horion",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Horion", targets: ["Horion"]),
        .library(name: "HorionKit", targets: ["HorionKit"]),
    ],
    targets: [
        .target(name: "HorionKit"),
        .executableTarget(
            name: "Horion",
            dependencies: ["HorionKit"],
            resources: [.copy("Resources/Fonts")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "HorionKitTests", dependencies: ["HorionKit"], resources: [.copy("Fixtures")]),
        .testTarget(name: "HorionTests", dependencies: ["Horion", "HorionKit"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
