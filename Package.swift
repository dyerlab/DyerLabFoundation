// swift-tools-version: 6.1
//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.

import PackageDescription

let package = Package(
    name: "DyerLabFoundation",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Matrix",             targets: ["Matrix"]),
        .library(name: "Graph",              targets: ["Graph"]),
        .library(name: "PresentationZen",    targets: ["PresentationZen"]),
        .library(name: "PopulationGenetics", targets: ["PopulationGenetics"]),
        .library(name: "DyerLabFoundation", targets: ["DyerlabFoundation"]),
    ],
    targets: [
        // MARK: - Library targets

        .target(
            name: "Matrix",
            cxxSettings: [
                .define("ACCELERATE_NEW_LAPACK", to: "1"),
            ],
            swiftSettings: [
                .define("SPM_BUILD"),
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
            linkerSettings: [
                .linkedFramework("Accelerate"),
            ]
        ),

        .target(
            name: "Graph",
            dependencies: ["Matrix"],
            swiftSettings: [
                .define("SPM_BUILD"),
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),

        .target(
            name: "PresentationZen",
            dependencies: ["Matrix", "Graph"],
            swiftSettings: [
                .define("SPM_BUILD"),
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),

        .target(
            name: "PopulationGenetics",
            dependencies: ["Matrix", "Graph", "PresentationZen"],
            // TODO: PopulationGenetics.docc resource processing deferred until
            // the target builds cleanly in its new home (see
            // DyerLabFoundation-Migration-Phase2.md) -- excluded rather than
            // processed for now.
            exclude: ["PopulationGenetics.docc"],
            swiftSettings: [
                .define("SPM_BUILD"),
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),

        .target(
            name: "DyerlabFoundation",
            dependencies: ["Matrix", "Graph", "PresentationZen", "PopulationGenetics"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),

        // MARK: - Test targets

        .testTarget(
            name: "MatrixTests",
            dependencies: ["Matrix"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),

        .testTarget(
            name: "GraphTests",
            dependencies: ["Graph"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),

        .testTarget(
            name: "PresentationZenTests",
            dependencies: ["PresentationZen"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),

        .testTarget(
            name: "PopulationGeneticsTests",
            dependencies: ["PopulationGenetics", "Matrix", "Graph", "PresentationZen"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),

        .testTarget(
            name: "DyerlabFoundationTests",
            dependencies: ["DyerlabFoundation"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
