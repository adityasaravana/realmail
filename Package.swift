// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RealMail",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RealMail", targets: ["RealMail"]),
    ],
    dependencies: [
        // No external dependencies - using Apple frameworks only
    ],
    targets: [
        // Main application target
        .executableTarget(
            name: "RealMail",
            dependencies: [],
            path: "RealMail",
            exclude: [
                "Resources/Assets.xcassets",
            ],
            sources: [
                "App",
                "Models",
                "Views",
                "ViewModels",
                "Services",
                "Utilities",
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Unit tests target
        .testTarget(
            name: "RealMailTests",
            dependencies: ["RealMail"],
            path: "Tests/RealMailTests"
        ),
    ]
)
