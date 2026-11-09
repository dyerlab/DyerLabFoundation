//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopulationGraphBuilder+PollenPools.swift
//  PopulationGenetics
//
//  The pollination graph (Dyer et al. 2004): a population graph whose nodes are maternal families and whose data
//  are the paternal gametes left once each mother's contribution is removed from her offspring (2Gener; Smouse et
//  al. 2001). Each node is a mother's pollen pool, drawn at her location, and its edges the conditional genetic
//  covariance among the pollen pools. Gametes are scored as in 2Gener: a resolved allele as its indicator, an
//  ambiguous one by its pollen-pool posterior, a missing one by the pollen-pool frequencies. Offspring that share
//  no allele with their mother at some locus are left out.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import CoreLocation
import Foundation
import Matrix

public extension PopulationGraphBuilder {

    /// The node level of a pollination graph: each maternal family's pollen pool.
    static let pollenPoolLevel = StructureSpec.familyLevel

    /// Estimates the pollination graph among maternal families from their offspring's paternal gametes.
    ///
    /// - Parameter dataset: Mothers and offspring.
    /// - Returns: The graph, one node per family with at least ``minimumPopulationSize`` gametes, stamped with the
    ///   dataset's fingerprint; `nil` with fewer than ``minimumPopulationCount`` such families or if the
    ///   decomposition fails.
    internal static func estimatePollenPools(from dataset: ImportedDataset) -> PopulationGraphDataset? {
        let families = dataset.parentage.families
        let gametes = TwoGenerGametes(matrix: dataset.matrix, design: dataset.parentage,
                                      method: .expectationMaximization, distances: false)
        var sizes: [Int: Int] = [:]
        for family in gametes.partition { sizes[family, default: 0] += 1 }
        let rows = gametes.partition.indices.filter { (sizes[gametes.partition[$0]] ?? 0) >= minimumPopulationSize }
        guard Set(rows.map { gametes.partition[$0] }).count >= minimumPopulationCount,
              let width = gametes.vectors.first?.count, width > 0 else { return nil }
        let x = Matrix(rows.count, width, 0.0)
        for (row, gamete) in rows.enumerated() {
            for (column, value) in gametes.vectors[gamete].enumerated() { x[row, column] = value }
        }
        let groups = rows.map { families[gametes.partition[$0]].id }
        guard let graph = PopulationGraph(x: x, groups: groups) else { return nil }

        let centroids = pollenPoolCentroids(in: dataset)
        let byID = Dictionary(families.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var nodeStrata: [UUID: [StratumReference]] = [:]
        for node in graph.nodes {
            node.coordinate = centroids[node.name]
            let mother = byID[node.name]?.mother.map { dataset.matrix.individuals[$0].id }
            let lineage = mother.flatMap { dataset.strata[$0] } ?? []
            nodeStrata[node.id] = lineage + [StratumReference(level: pollenPoolLevel, name: node.name)]
        }
        return PopulationGraphDataset(graph: graph, nodeStrata: nodeStrata,
                                      graphValues: [fingerprintKey: pollenPoolFingerprint(of: dataset)],
                                      loci: dataset.matrix.loci)
    }

    /// Each family's location: its mother's, when she has coordinates.
    ///
    /// - Parameter dataset: Mothers and offspring.
    /// - Returns: The mothers' coordinates, by family.
    internal static func pollenPoolCentroids(in dataset: ImportedDataset) -> [String: CLLocationCoordinate2D] {
        var centroids: [String: CLLocationCoordinate2D] = [:]
        for family in dataset.familiesWithOffspring {
            guard let mother = family.mother else { continue }
            let individual = dataset.matrix.individuals[mother]
            if let latitude = individual.latitude, let longitude = individual.longitude {
                centroids[family.id] = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
        }
        return centroids
    }

    /// A stable hash of every family's members, mother and offspring, and their genotypes.
    ///
    /// - Parameter dataset: Mothers and offspring.
    /// - Returns: The fingerprint.
    internal static func pollenPoolFingerprint(of dataset: ImportedDataset) -> Double {
        let members = dataset.familiesWithOffspring.flatMap { family in
            ((family.mother.map { [$0] } ?? []) + family.offspring).map { (family.id, $0) }
        }
        return fingerprint(of: members, in: dataset)
    }
}
