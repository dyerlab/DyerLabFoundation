//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphNodeAttributeUpdate.swift
//  PopulationGenetics
//
//  A set of node attributes to replace in a stored graph, addressed by node
//  name so it can apply to a graph another program has since rewritten. Only
//  the named attributes change, so a later edit to any other value survives.
//
//  Created by Rodney Dyer on 2026.11.05.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Graph

/// Node attributes to replace in a stored graph, leaving all others alone.
public struct GraphNodeAttributeUpdate: Sendable, Equatable {

    /// The attributes being replaced, including any that have become empty.
    public let attributes: Set<String>

    /// The names of the nodes the update was made for.
    public let nodeNames: Set<String>

    /// New numeric values by node name, then attribute.
    public let values: [String: [String: Double]]

    /// New text labels by node name, then attribute.
    public let labels: [String: [String: String]]

    /// Captures the named attributes from a graph.
    ///
    /// - Parameters:
    ///   - attributes: The attributes to replace.
    ///   - graph: The graph holding their new contents.
    public init(attributes: Set<String>, from graph: GraphSnapshot) {
        self.attributes = attributes
        nodeNames = Set(graph.nodes.map(\.name))
        var values: [String: [String: Double]] = [:]
        var labels: [String: [String: String]] = [:]
        for node in graph.nodes {
            values[node.name] = node.continuousAttributes.filter { attributes.contains($0.key) && $0.value.isFinite }
            labels[node.name] = node.categoricalAttributes.filter { attributes.contains($0.key) }
        }
        self.values = values
        self.labels = labels
    }

    /// Applies this update to a stored graph.
    ///
    /// - Parameter dataset: The graph as it stands on disk.
    /// - Returns: The same graph with the named attributes replaced. An attribute
    ///   that already exists keeps its intrinsic or extrinsic kind.
    /// - Throws: ``GraphsFileError/nodesChanged`` if the update's nodes aren't exactly the graph's.
    public func applied(to dataset: PopulationGraphDataset) throws -> PopulationGraphDataset {
        guard !attributes.isEmpty else { return dataset }
        guard Set(dataset.graph.nodes.map(\.name)) == nodeNames else { throw GraphsFileError.nodesChanged }

        var strataIDs: [StratumKey: UUID] = [:]
        var kinds: [String: GraphValue.Kind] = [:]
        for reference in dataset.nodeStrata.values.joined() {
            strataIDs[StratumKey(level: reference.level, name: reference.name)] = reference.id
        }
        for value in dataset.nodeValues.values.joined() { kinds[value.name] = value.kind }

        var nodeStrata: [UUID: [StratumReference]] = [:]
        var nodeValues: [UUID: [GraphValue]] = [:]
        for node in dataset.graph.nodes {
            var references = (dataset.nodeStrata[node.id] ?? []).filter { !attributes.contains($0.level) }
            for (level, name) in labels[node.name] ?? [:] {
                let key = StratumKey(level: level, name: name)
                let id = strataIDs[key] ?? UUID()
                strataIDs[key] = id
                references.append(StratumReference(id: id, level: level, name: name))
            }
            var measures = (dataset.nodeValues[node.id] ?? []).filter { !attributes.contains($0.name) }
            for (name, value) in values[node.name] ?? [:] {
                measures.append(GraphValue(name: name, value: value, kind: kinds[name] ?? .intrinsic))
            }
            if !references.isEmpty { nodeStrata[node.id] = references }
            if !measures.isEmpty { nodeValues[node.id] = measures }
        }
        return PopulationGraphDataset(graph: dataset.graph, nodeStrata: nodeStrata, nodeValues: nodeValues,
                                      edgeValues: dataset.edgeValues, graphValues: dataset.graphValues,
                                      loci: dataset.loci)
    }

    private struct StratumKey: Hashable {
        let level: String
        let name: String
    }
}
