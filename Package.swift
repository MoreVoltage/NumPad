// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "NumPad",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "NumPad",
            targets: ["NumPad"]
        )
    ],
    targets: [
        .target(
            name: "NumPad",
            path: "NumPad/Libraries",
            sources: [
                "SharedExtensions.swift",
                "Keyboard.swift"
            ]
        )
    ]
)
