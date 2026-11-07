//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityPlotOptions.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The choices a dataset offers for a diversity plot, and the groups of
/// individuals behind them.
///
/// Population statistics use the adults, so that offspring don't count as extra
/// samples of their mothers' generation. Family statistics use the offspring.
public struct DiversityPlotOptions: Sendable {

    /// A set of individuals that diversity is computed within.
    public struct Group: Sendable, Equatable {
        /// The population's name or family's label.
        public let name: String
        /// The individuals' rows in the genotype matrix.
        public let ordinals: [Int]

        /// Creates a group.
        ///
        /// - Parameters:
        ///   - name: The population's name or family's label.
        ///   - ordinals: The individuals' rows in the genotype matrix.
        public init(name: String, ordinals: [Int]) {
            self.name = name
            self.ordinals = ordinals
        }
    }

    /// Every locus name, in matrix order.
    public let loci: [String]
    /// The populations, in natural sort order.
    public let populations: [Group]
    /// The maternal families that have offspring.
    public let families: [Group]
    /// Whether any group has coordinates.
    public let hasCoordinates: Bool

    /// Reads the choices from a dataset.
    ///
    /// - Parameter dataset: The genotypes.
    public init(dataset: ImportedDataset) {
        loci = dataset.matrix.loci.map(\.name)

        let adults = dataset.adultOrdinals
        let byPopulation = Dictionary(grouping: adults.filter { !dataset.populationName(at: $0).isEmpty }) {
            dataset.populationName(at: $0)
        }
        populations = byPopulation.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { Group(name: $0, ordinals: byPopulation[$0] ?? []) }

        families = dataset.familiesWithOffspring.map { Group(name: $0.id, ordinals: $0.offspring) }

        let individuals = dataset.matrix.individuals
        hasCoordinates = individuals.contains { $0.latitude != nil && $0.longitude != nil }
    }

    /// The kind of group continuous predictors and sample filters use:
    /// populations if there are any, otherwise families.
    public var primaryGroupUnit: DiversityPlotSpec.Unit { populations.isEmpty ? .family : .population }

    /// The groups of the primary kind.
    public var primaryGroups: [Group] { populations.isEmpty ? families : populations }

    /// What the primary groups are called, in the plural.
    public var primaryGroupsTitle: String { populations.isEmpty ? "families" : "populations" }

    /// The predictors this dataset can support.
    public var predictors: [DiversityPlotSpec.Predictor] {
        DiversityPlotSpec.Predictor.allCases.filter { isAvailable($0) }
    }

    /// The distribution units this dataset can support.
    public var units: [DiversityPlotSpec.Unit] {
        var units: [DiversityPlotSpec.Unit] = [.locus]
        if !populations.isEmpty { units += [.population, .locusWithinPopulation] }
        if !families.isEmpty { units += [.family, .locusWithinFamily] }
        return units
    }

    /// Whether a predictor has the data behind it.
    ///
    /// - Parameter predictor: The predictor to check.
    /// - Returns: `true` when the dataset can draw plots against `predictor`.
    public func isAvailable(_ predictor: DiversityPlotSpec.Predictor) -> Bool {
        switch predictor {
        case .none, .locus: true
        case .population: !populations.isEmpty
        case .family: !families.isEmpty
        case .latitude, .longitude: hasCoordinates && !primaryGroups.isEmpty
        case .sampleSize: !primaryGroups.isEmpty
        }
    }

    /// The groups behind a per-group unit.
    ///
    /// - Parameter unit: The unit.
    /// - Returns: The families for family units, otherwise the populations.
    public func groups(for unit: DiversityPlotSpec.Unit) -> [Group] {
        unit == .family || unit == .locusWithinFamily ? families : populations
    }
}
