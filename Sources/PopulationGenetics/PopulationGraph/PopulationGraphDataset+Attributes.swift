//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopulationGraphDataset+Attributes.swift
//  PopulationGenetics
//
//  Converts between a dataset's stored strata and values and the open attribute
//  dictionaries on `Node`, which the store itself doesn't write.
//
//  Created by Rodney Dyer on 2026.11.05.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Graph

extension PopulationGraphDataset {

    /// Creates a dataset whose stored strata and values come from its nodes'
    /// attributes: text attributes become single-level strata, and numeric ones
    /// become intrinsic values. Nodes sharing a label share one stratum.
    ///
    /// - Parameter graph: The graph to store.
    public init(attributesOf graph: GraphSnapshot) {
        var strataIDs: [String: [String: UUID]] = [:]
        var nodeStrata: [UUID: [StratumReference]] = [:]
        var nodeValues: [UUID: [GraphValue]] = [:]
        for node in graph.nodes {
            let references = node.categoricalAttributes.map { level, name in
                let id = strataIDs[level]?[name] ?? UUID()
                strataIDs[level, default: [:]][name] = id
                return StratumReference(id: id, level: level, name: name)
            }
            let values = node.continuousAttributes.filter(\.value.isFinite).map { name, value in
                GraphValue(name: name, value: value, kind: .intrinsic)
            }
            if !references.isEmpty { nodeStrata[node.id] = references }
            if !values.isEmpty { nodeValues[node.id] = values }
        }
        self.init(graph: graph, nodeStrata: nodeStrata, nodeValues: nodeValues)
    }

    /// Builds a live graph whose nodes also carry this dataset's strata and
    /// values as attributes. A node with several strata at one level takes the
    /// first by name.
    ///
    /// - Returns: A fresh graph with the original identifiers.
    public func makeGraphWithAttributes() -> Graph {
        let live = makeGraph()
        for node in live.nodes {
            for value in nodeValues[node.id] ?? [] {
                node.continuousAttributes[value.name] = value.value
            }
            for reference in (nodeStrata[node.id] ?? []).sorted(by: { $0.name > $1.name }) {
                node.categoricalAttributes[reference.level] = reference.name
            }
        }
        return live
    }
}
