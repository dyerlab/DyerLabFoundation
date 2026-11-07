//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeSummary.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.10.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Headline counts for an imported dataset.
public struct GenotypeSummary: Sendable {

    /// One population's sample size and mean location.
    public struct Population: Identifiable, Sendable {
        /// The population's name.
        public var id: String { name }
        /// The population's name, as given in the CSV.
        public let name: String
        /// The number of individuals sampled.
        public let count: Int
        /// The mean latitude of the individuals that have one, in decimal degrees.
        public let latitude: Double?
        /// The mean longitude of the individuals that have one, in decimal degrees.
        public let longitude: Double?
    }

    /// The number of individuals in the dataset.
    public let individualCount: Int

    /// The number of loci in the dataset.
    public let locusCount: Int

    /// Every population, in natural sort order (`Pop2` before `Pop10`).
    public let populations: [Population]

    /// Whether any population has coordinates.
    public var isSpatial: Bool {
        populations.contains { $0.latitude != nil && $0.longitude != nil }
    }

    /// Summarises a dataset by its innermost stratum.
    ///
    /// - Parameter dataset: The imported genotypes.
    public init(dataset: ImportedDataset) {
        let matrix = dataset.matrix
        individualCount = matrix.individualCount
        locusCount = matrix.locusCount

        let byPopulation = Dictionary(grouping: matrix.individuals) { individual in
            dataset.strata[individual.id]?.last?.name ?? "—"
        }
        populations = byPopulation.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { name in
            let members = byPopulation[name] ?? []
            return Population(name: name,
                              count: members.count,
                              latitude: Self.mean(members.compactMap(\.latitude)),
                              longitude: Self.mean(members.compactMap(\.longitude)))
        }
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
