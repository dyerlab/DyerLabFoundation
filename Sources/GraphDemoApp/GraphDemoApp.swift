//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphDemoApp.swift
//  GraphDemoApp
//
//  A minimal demo app, compiled for iOS/macOS/visionOS from this one Package.swift
//  target, showing the bundled lopho population graph via the non-spatial (Canvas-
//  based) GraphLayoutView. On visionOS this opens as an ordinary flat window
//  (WindowGroup's default), not a `.windowStyle(.volumetric)` scene — deliberately
//  non-spatial, as a baseline for the eventual RealityGraphView demo.
//
//  This target exists to let the views in this package actually be run and looked
//  at (Xcode's canvas #Preview mechanism can't stand in for a real per-platform
//  run) — open Package.swift in Xcode, pick the GraphDemoApp scheme, and choose
//  any iOS/macOS/visionOS simulator or device destination.
//
//  Created by Rodney Dyer on 2026.08.09.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Graph
import SwiftUI

@main
struct GraphDemoApp: App {
    var body: some Scene {
        WindowGroup {
            GraphLayoutView(graph: Graph.lophoGraph, configuration: .distanceWeightedGraph())
        }
    }
}
