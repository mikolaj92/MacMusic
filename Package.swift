// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MiniMaxMusic",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MiniMaxMusic", targets: ["MiniMaxMusic"])
    ],
    dependencies: [
        .package(url: "https://github.com/mikolaj92/minimax-music3-swift", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "MiniMaxMusic",
            dependencies: [
                .product(name: "MiniMaxMusic3MLX", package: "minimax-music3-swift")
            ]
        )
    ]
)
