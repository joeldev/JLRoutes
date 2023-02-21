// swift-tools-version:5.4

import PackageDescription

let package = Package(
    name: "JLRoutes",
    platforms: [
        .macOS(.v10_10),
        .iOS(.v9),
        .tvOS(.v9),
    ],
    products: [
        .library(
            name: "JLRoutes",
            targets: ["JLRoutes"]
        ),
    ],
    targets: [
        .target(
            name: "JLRoutes",
            path: "JLRoutes",
            publicHeadersPath: "."
        ),
    ],
    swiftLanguageVersions: [.v5]
)
