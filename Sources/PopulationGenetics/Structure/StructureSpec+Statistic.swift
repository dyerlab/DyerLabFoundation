//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureSpec+Statistic.swift
//  PopulationGenetics
//
//  The statistics a variance-components table can show, with the wording the
//  controls, legends and Methods share. Raw values are stored; don't change
//  them.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

public extension StructureSpec {

    /// The statistic of a variance-components table.
    enum Statistic: String, CaseIterable, Identifiable, Codable, Sendable {
        /// Φ_ST from an AMOVA of gene copies, each individual contributing two.
        case phiGeneCopies
        /// Φ_ST from an AMOVA of individuals, with Smouse & Peakall's genotype distances (GenAlEx).
        case phiGenotypes
        /// Weir & Cockerham's θ, with F_IS and F_IT.
        case theta
        /// Φ_ST from an AMOVA of paternal gametes (2Gener).
        case phiGametes

        /// The statistic itself.
        public var id: Self { self }

        /// The statistics a sample offers, its default first.
        ///
        /// - Parameter sample: Whose genotypes are analysed.
        /// - Returns: The choices.
        static func choices(for sample: Sample) -> [Statistic] {
            sample == .adults ? [.phiGeneCopies, .phiGenotypes, .theta] : [.phiGametes]
        }

        /// The statistic's name in menus.
        public var title: String {
            switch self {
            case .phiGeneCopies: "Φ_ST from gene copies"
            case .phiGenotypes: "Φ_ST from genotypes"
            case .theta: "Weir & Cockerham θ"
            case .phiGametes: "Φ_ST from paternal gametes"
            }
        }

        /// The statistic's symbol.
        public var symbol: String { self == .theta ? "θ" : "Φ_ST" }

        /// The R-safe name of the statistic's column in a variance-components table.
        var columnName: String { self == .theta ? "F" : "Phi_ST" }

        /// What the statistic is, in a sentence for the controls and legends.
        public var summary: String {
            switch self {
            case .phiGeneCopies:
                "An AMOVA of allele copies, two per individual (Excoffier et al. 1992). It is close to Weir & "
                    + "Cockerham's θ, without a level for individuals."
            case .phiGenotypes:
                "An AMOVA of individuals with Smouse & Peakall's (1999) genotype distances, as in GenAlEx. Without "
                    + "a level within individuals it runs higher than θ, about 2θ/(1 + θ) under Hardy–Weinberg."
            case .theta:
                "Weir & Cockerham's (1984) nested analysis of variance among strata, among individuals within "
                    + "strata and within individuals, giving θ with F_IS and F_IT."
            case .phiGametes:
                "An AMOVA of the paternal gametes left once each mother's contribution is removed (2Gener; Smouse "
                    + "et al. 2001), giving Φ_ST among the pollen pools of maternal families (their Φ_FT)."
            }
        }

        /// The units the statistic partitions, for prose.
        var units: String {
            switch self {
            case .phiGeneCopies: "gene copies"
            case .phiGenotypes, .theta: "individuals"
            case .phiGametes: "paternal gametes"
            }
        }

        /// The by-locus column that holds this statistic.
        var column: Column {
            switch self {
            case .phiGeneCopies: .phiGeneCopies
            case .phiGenotypes: .phiGenotypes
            case .theta: .theta
            case .phiGametes: .phiGametes
            }
        }
    }
}
