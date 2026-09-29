// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Calendr",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Calendr", targets: ["Calendr"]),
        .library(name: "CalendrKit", targets: ["CalendrKit"]),
    ],
    targets: [
        .target(name: "CalendrKit"),
        .executableTarget(
            name: "Calendr",
            dependencies: ["CalendrKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "CalendrKitTests", dependencies: ["CalendrKit"]),
        .testTarget(name: "CalendrTests", dependencies: ["Calendr", "CalendrKit"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
