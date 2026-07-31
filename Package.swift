// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WooDisplay",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WooDisplay", targets: ["WooDisplay"])
    ],
    targets: [
        .executableTarget(
            name: "WooDisplay",
            path: "Sources/WooDisplay"
        )
    ]
)
