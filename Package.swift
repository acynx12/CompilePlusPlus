// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CompilePlusPlus",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CompilePlusPlus", targets: ["CompilePlusPlus"])
    ],
    targets: [
        .target(
            name: "SwiftTerm",
            path: "Vendor/SwiftTerm/Sources/SwiftTerm",
            exclude: [
                "Documentation.docc",
                "Apple/Metal/Shaders.metal",
                "Mac/README.md",
                "iOS"
            ]
        ),
        .executableTarget(
            name: "CompilePlusPlus",
            dependencies: ["SwiftTerm"],
            path: "Sources/CompilePlusPlus"
        )
    ],
    swiftLanguageModes: [.v6]
)
