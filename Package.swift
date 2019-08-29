// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "JLRoutes",
    platforms: [.iOS(.v8)],
    products: [
        .library(
            name: "JLRoutes",
            targets: ["JLRoutes"]),
    ],
    targets: [
        .target(
            name: "JLRoutes",
            path: "JLRoutes",
            cSettings: [
                .headerSearchPath("."),
                .headerSearchPath("Classes"),
            ]),
    ]
)
