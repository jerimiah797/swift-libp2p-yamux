// swift-tools-version: 6.0
//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-libp2p open source project
//
// Copyright (c) 2022-2025 swift-libp2p project authors
// Licensed under MIT
//
// See LICENSE for license information
// See CONTRIBUTORS for the list of swift-libp2p project authors
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "swift-libp2p-yamux",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LibP2PYAMUX",
            targets: ["LibP2PYAMUX"]
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.

        // LibP2P Core Modules
        // jerimiah797/swift-libp2p (burrows-impl): tag 0.3.5 +
        // defensive guards for post-shutdown property access.
        // Repinned away from the upstream URL so downstream
        // Burrows doesn't hit a SwiftPM "conflicting identity"
        // warning between two repos that both claim the
        // `swift-libp2p` package identity (see also the matching
        // change in jerimiah797/swift-libp2p-kad-dht).
        .package(
            url: "https://github.com/jerimiah797/swift-libp2p.git",
            revision: "02e64b133e1383e02ccb2d68acb04366747c16f8"
        ),

        // NIO Test Utils
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMajor(from: "2.0.0")),

    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LibP2PYAMUX",
            dependencies: [
                .product(name: "LibP2P", package: "swift-libp2p")
            ]
        ),
        .testTarget(
            name: "LibP2PYAMUXTests",
            dependencies: [
                "LibP2PYAMUX",
                .product(name: "NIOTestUtils", package: "swift-nio"),
            ]
        ),
    ]
)
