//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PairwiseScatter+Samples.swift
//  PresentationZen
//
//  Preview data from a real dataset: the bundled Lophocereus schottii
//  population graph (21 populations along the Baja California peninsula),
//  run through the same analyses an app would use.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Graph
import Matrix

extension PairwiseScatter {

    /// Conditional genetic distance against great-circle distance (km) for
    /// every connected pair of Lophocereus populations, with its fitted line.
    public static var sampleGraphDistance: PairwiseScatter {
        let graph = sampleLophoGraph()
        let nodes = graph.nodes
        let names = nodes.map(\.name)
        let km = Matrix(nodes.count, nodes.count, names, names)
        for (i, a) in nodes.enumerated() {
            for (j, b) in nodes.enumerated() where i != j {
                if let p = a.coordinate, let q = b.coordinate { km[i, j] = distanceBetween(p, q) }
            }
        }
        return IsolationByGraphDistanceAnalysis(graph: graph, separation: .distances(km, forward: nil),
                                                separationLabel: "Distance (km)")?
            .run(options: AnalysisOptions(iterations: 0))?
            .scatter ?? PairwiseScatter(xLabel: "Distance (km)", yLabel: "cGD", series: [])
    }

    /// Partitioned genetic distance against latitude difference for the
    /// Lophocereus populations, split into northward (forward) and southward
    /// (reverse) pairs, each with its own fitted slope.
    public static var sampleDirectionalGraphDistance: PairwiseScatter {
        let graph = sampleLophoGraph()
        let latitude = Dictionary(uniqueKeysWithValues: graph.nodes.compactMap { node in
            node.coordinate.map { (node.name, $0.latitude) }
        })
        return DirectionalIsolationByGraphDistanceAnalysis(graph: graph, separation: .positions(latitude),
                                                           separationLabel: "Latitude difference (°)")?
            .run(options: AnalysisOptions(iterations: 0))?
            .scatter ?? PairwiseScatter(xLabel: "Latitude difference (°)", yLabel: "pGD", series: [])
    }

    /// The bundled Lophocereus graph; a missing resource is a packaging bug.
    private static func sampleLophoGraph() -> Graph {
        try! Graph.importGeoJSON(contentsOf: try! GraphExampleData.url("lopho", extension: "geojson"))
    }
}
