//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureSpec.swift
//  PopulationGenetics
//
//  The parameters of a structure table, stored as JSON in a saved figure's
//  `spec`, so the raw values of its enums must not change. Specs saved before
//  tables had a kind, a statistic and columns read as the table they made then:
//  an AMOVA of genotypes for every adult locus, θ for one adult locus, and an
//  AMOVA of gametes for offspring. Specs saved before Hs and Ht had a choice of
//  estimator read as Jost's form, the only one then.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The parameters of a genetic structure analysis: whose genotypes, which table and statistics, which loci and
/// strata, and the test.
///
/// | Table | Shows |
/// |---|---|
/// | ``Table/amova`` | the analysis of variance behind one ``Statistic``, at one locus or summed over loci |
/// | ``Table/perLocus`` | one row per locus, then the multilocus row, with the chosen ``Column``s |
///
/// Multilocus values are always ratios of sums over loci, never means of the per-locus values.
public struct StructureSpec: Codable, Hashable, Sendable {

    /// Whose genotypes are analysed.
    public enum Sample: String, CaseIterable, Identifiable, Codable, Sendable {
        /// The adults, each a diploid individual.
        case adults
        /// The offspring's paternal gametes, left once each mother's contribution is removed (2Gener).
        case paternalGametes

        /// The sample itself.
        public var id: Self { self }

        /// The sample's name in menus.
        public var title: String {
            switch self {
            case .adults: "Adults"
            case .paternalGametes: "Paternal gametes"
            }
        }
    }

    /// Which table is made.
    public enum Table: String, CaseIterable, Identifiable, Codable, Sendable {
        /// The analysis of variance behind one statistic.
        case amova
        /// One row per locus, then the multilocus row.
        case perLocus

        /// The table itself.
        public var id: Self { self }

        /// The table's name in menus.
        public var title: String {
            switch self {
            case .amova: "Variance components"
            case .perLocus: "By locus"
            }
        }
    }

    /// The stratum level that groups offspring by their mother.
    public static let familyLevel = "Family"

    /// The default number of permutations.
    public static let defaultPermutations = 999

    /// Whose genotypes are analysed.
    public var sample: Sample
    /// Which table is made.
    public var table: Table
    /// The statistic a variance-components table shows.
    public var statistic: Statistic
    /// The statistics a by-locus table shows, in order.
    public var columns: [Column]
    /// How a by-locus table estimates Hs and Ht, and so Gst, G′st and Dest.
    public var heterozygosity: Heterozygosity
    /// The one locus analysed, or `nil` for every locus.
    public var locus: String?
    /// The stratum level that groups the sample, such as `Population` or ``familyLevel``.
    public var level: String
    /// The number of permutations testing the statistics, or 0 for no test.
    public var permutations: Int
    /// The permutations' random seed, or `nil` if there is no test.
    public var seed: UInt64?
    /// When a locus's Gst or Dest is flagged.
    public var thresholds: DifferentiationThresholds

    /// Creates the parameters.
    ///
    /// - Parameters:
    ///   - sample: Whose genotypes are analysed.
    ///   - table: Which table is made (default the variance components).
    ///   - statistic: The statistic of a variance-components table, or `nil` for the sample's default.
    ///   - columns: The statistics of a by-locus table, or `nil` for the sample's default.
    ///   - heterozygosity: How a by-locus table estimates Hs and Ht.
    ///   - locus: The one locus analysed, or `nil` for every locus.
    ///   - level: The stratum level that groups the sample.
    ///   - permutations: The number of permutations, or 0 for no test.
    ///   - seed: The permutations' random seed.
    ///   - thresholds: When a locus's Gst or Dest is flagged.
    public init(sample: Sample = .adults,
                table: Table = .amova,
                statistic: Statistic? = nil,
                columns: [Column]? = nil,
                heterozygosity: Heterozygosity = .standard,
                locus: String? = nil,
                level: String,
                permutations: Int = 0,
                seed: UInt64? = nil,
                thresholds: DifferentiationThresholds = DifferentiationThresholds()) {
        self.sample = sample
        self.table = table
        self.statistic = statistic ?? Statistic.choices(for: sample)[0]
        self.columns = columns ?? Column.defaults(for: sample)
        self.heterozygosity = heterozygosity
        self.locus = locus
        self.level = level
        self.permutations = max(0, permutations)
        self.seed = permutations > 0 ? seed : nil
        self.thresholds = thresholds
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case sample, table, statistic, columns, heterozygosity, locus, level, permutations, seed, thresholds
    }

    /// Reads a spec, giving one saved before tables had a kind, statistic, columns or Hs estimator the table it
    /// made then.
    ///
    /// - Parameter decoder: The decoder.
    /// - Throws: `DecodingError` if the sample or level is missing or unreadable.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sample = try container.decode(Sample.self, forKey: .sample)
        locus = try container.decodeIfPresent(String.self, forKey: .locus)
        level = try container.decode(String.self, forKey: .level)
        permutations = try container.decodeIfPresent(Int.self, forKey: .permutations) ?? 0
        seed = try container.decodeIfPresent(UInt64.self, forKey: .seed)
        table = try container.decodeIfPresent(Table.self, forKey: .table) ?? .amova
        let earlier: Statistic = sample == .paternalGametes ? .phiGametes : locus == nil ? .phiGenotypes : .theta
        statistic = try container.decodeIfPresent(Statistic.self, forKey: .statistic) ?? earlier
        columns = try container.decodeIfPresent([Column].self, forKey: .columns) ?? Column.defaults(for: sample)
        heterozygosity = try container.decodeIfPresent(Heterozygosity.self, forKey: .heterozygosity)
            ?? Heterozygosity.earlier
        thresholds = try container.decodeIfPresent(DifferentiationThresholds.self, forKey: .thresholds)
            ?? DifferentiationThresholds()
    }

    // MARK: - Describing

    /// Whether the statistics are tested by permutation.
    public var isTested: Bool { permutations > 0 }

    /// The columns a by-locus table tests, in order.
    public var testedColumns: [Column] { columns.filter(\.isTestable) }

    /// The symbol of the statistic a test follows: the variance-components statistic, or a by-locus table's
    /// first testable column.
    public var statisticLabel: String {
        switch table {
        case .amova: statistic.symbol
        case .perLocus: testedColumns.first?.header ?? statistic.symbol
        }
    }

    /// A title for the table, such as `"AMOVA among populations"`.
    public var title: String {
        let groups = Self.plural(level)
        let loci = locus.map { " at \($0)" } ?? ""
        switch (table, statistic) {
        case (.perLocus, _): return "Differentiation among \(groups) by locus\(loci)"
        case (.amova, .theta): return "θ among \(groups)\(loci)"
        case (.amova, .phiGametes): return "Paternal gametes among \(groups)\(loci)"
        case (.amova, _): return "AMOVA among \(groups)\(loci)"
        }
    }

    /// A stratum level's name as a lowercase plural, for prose: `Population` gives `populations`.
    ///
    /// - Parameter level: The level's name.
    /// - Returns: The plural.
    public static func plural(_ level: String) -> String {
        let word = level.lowercased()
        if word.isEmpty { return "strata" }
        if word.hasSuffix("y"), let last = word.dropLast().last, !"aeiou".contains(last) {
            return word.dropLast() + "ies"
        }
        if word.hasSuffix("s") || word.hasSuffix("x") || word.hasSuffix("ch") || word.hasSuffix("sh") {
            return word + "es"
        }
        return word + "s"
    }
}
