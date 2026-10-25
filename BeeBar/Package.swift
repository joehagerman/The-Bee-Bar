// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BeeBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BeeBar", targets: ["BeeBar"])
    ],
    targets: [
        .executableTarget(
            name: "BeeBar",
            path: "Sources/BeeBar"
        )
    ]
)
