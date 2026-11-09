//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StratumReport.swift
//  PopulationGenetics
//
//  The stratum counterpart of `FamilyReport`: what a population, region or other stratum holds, read before any
//  analysis. Diversity is computed over the adults only, since offspring repeat their mothers' alleles; offspring are
//  counted but kept out of the numbers. The multilocus F is a ratio of sums, 1 − ΣHo / ΣHe, like every multilocus
//  statistic in the package; the other multilocus values are means over the loci genotyped here.
//
//  Created by Rodney Dyer on 2026.11.09.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// One stratum's members and per-locus diversity.
public struct StratumReport: Sendable {

    /// One locus's diversity among the stratum's adults.
    public struct LocusRow: Identifiable, Sendable {
        /// The locus's name.
        public let locus: String
        /// The adults genotyped at the locus.
        public let genotyped: Int
        /// The number of alleles.
        public let alleles: Double?
        /// The effective number of alleles, 1 / Σp².
        public let effectiveAlleles: Double?
        /// Observed heterozygosity.
        public let ho: Double?
        /// Expected heterozygosity, 1 − Σp².
        public let he: Double?

        /// The locus's name.
        public var id: String { locus }

        /// The inbreeding coefficient, 1 − Ho / He, or `nil` when He is zero or unknown.
        public var f: Double? {
            guard let ho, let he, he > 0 else { return nil }
            return 1 - ho / he
        }
    }

    /// The strata level, such as Population.
    public let level: String
    /// The stratum's name.
    public let name: String
    /// The strata the stratum sits within, outermost first, such as `["Control"]` for a cluster in a treatment.
    public let parents: [String]
    /// Every member's row in the matrix, adults and offspring, in matrix order.
    public let ordinals: [Int]
    /// The adults' rows: every member, or only the mothers in parent/offspring data.
    public let adults: [Int]
    /// How many adults have coordinates.
    public let locatedCount: Int
    /// The adults' mean latitude, if any has coordinates.
    public let latitude: Double?
    /// The adults' mean longitude, if any has coordinates.
    public let longitude: Double?
    /// Each locus's diversity among the adults, in matrix order.
    public let loci: [LocusRow]

    // MARK: - Initialization

    /// Summarises one stratum.
    ///
    /// - Parameters:
    ///   - dataset: The genotypes, with strata.
    ///   - level: The strata level.
    ///   - name: The stratum's name within that level.
    public init(dataset: ImportedDataset, level: String, name: String) {
        let individuals = dataset.matrix.individuals
        let adultSet = Set(dataset.adultOrdinals)
        var ordinals: [Int] = []
        var parents: [String] = []
        for ordinal in individuals.indices {
            let lineage = dataset.strata[individuals[ordinal].id] ?? []
            guard let depth = lineage.firstIndex(where: { $0.level == level && $0.name == name }) else { continue }
            if ordinals.isEmpty { parents = lineage[..<depth].map(\.name) }
            ordinals.append(ordinal)
        }
        let adults = ordinals.filter(adultSet.contains)
        let located = adults.compactMap { ordinal -> (Double, Double)? in
            guard let latitude = individuals[ordinal].latitude, let longitude = individuals[ordinal].longitude else {
                return nil
            }
            return (latitude, longitude)
        }
        self.level = level
        self.name = name
        self.parents = parents
        self.ordinals = ordinals
        self.adults = adults
        locatedCount = located.count
        latitude = located.isEmpty ? nil : located.map(\.0).reduce(0, +) / Double(located.count)
        longitude = located.isEmpty ? nil : located.map(\.1).reduce(0, +) / Double(located.count)
        loci = dataset.matrix.loci.indices.map { locus in
            let frequencies = dataset.matrix.frequencies(atLocus: locus, over: adults)
            let genotyped = Int(frequencies.numGenos)
            return LocusRow(locus: dataset.matrix.loci[locus].name, genotyped: genotyped,
                            alleles: DiversityType.A.value(of: frequencies),
                            effectiveAlleles: DiversityType.Ae.value(of: frequencies),
                            ho: DiversityType.Ho.value(of: frequencies),
                            he: DiversityType.He.value(of: frequencies))
        }
    }

    // MARK: - Contents

    /// How many offspring the stratum holds besides its adults.
    public var offspringCount: Int {
        ordinals.count - adults.count
    }

    /// The multilocus row: means over the loci genotyped here, with F as 1 − ΣHo / ΣHe and the fewest adults
    /// genotyped at any of them.
    public var multilocus: LocusRow {
        let typed = loci.filter { $0.genotyped > 0 }
        /// The mean of a column over the typed loci.
        func mean(_ value: (LocusRow) -> Double?) -> Double? {
            let values = typed.compactMap(value)
            return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }
        let ho = typed.compactMap(\.ho).reduce(0, +), he = typed.compactMap(\.he).reduce(0, +)
        let count = Double(typed.count)
        return LocusRow(locus: "Multilocus", genotyped: typed.map(\.genotyped).min() ?? 0,
                        alleles: mean(\.alleles), effectiveAlleles: mean(\.effectiveAlleles),
                        ho: typed.isEmpty ? nil : ho / count, he: typed.isEmpty ? nil : he / count)
    }

    /// The strata of a level, in the order first met in the data.
    ///
    /// - Parameters:
    ///   - level: The strata level.
    ///   - dataset: The genotypes, with strata.
    /// - Returns: The strata's names.
    public static func strata(of level: String, in dataset: ImportedDataset) -> [String] {
        var names: [String] = []
        var seen: Set<String> = []
        for individual in dataset.matrix.individuals {
            for reference in dataset.strata[individual.id] ?? [] where reference.level == level {
                if seen.insert(reference.name).inserted { names.append(reference.name) }
            }
        }
        return names
    }
}
