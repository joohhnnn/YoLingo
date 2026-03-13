// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "YoLingo",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "YoLingo", targets: ["YoLingo"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMajor(from: "6.29.0")),
        // .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "YoLingo",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                // .product(name: "HotKey", package: "HotKey"),
            ],
            path: "YoLingo",
            exclude: [
                "Resources/Info.plist",
                "Resources/YoLingo.entitlements",
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "YoLingoTests",
            dependencies: ["YoLingo"],
            path: "YoLingoTests"
        ),
    ]
)
