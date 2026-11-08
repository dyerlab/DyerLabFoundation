//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureSpec+Heterozygosity.swift
//  PopulationGenetics
//
//  The estimators of Hs and Ht that Gst, G′st and Dest are built from. They
//  differ in how they correct for sample size, and the choice moves every one
//  of those columns, so the controls offer it rather than burying one in a
//  citation. With ñ the harmonic mean of the strata sizes, k the strata, p̄ the
//  unweighted mean of the strata frequencies and Ho the mean observed
//  heterozygosity:
//
//  - Nei & Chesser (1983; hierfstat's basic.stats):
//    Hs = ñ/(ñ − 1) · (1 − mean Σp² − Ho/2ñ),
//    Ht = 1 − Σp̄² + Hs/kñ − Ho/2kñ,
//  - Jost (2008, eq. 12; mmod), which assumes Hardy–Weinberg within strata:
//    Hs = 2ñ/(2ñ − 1) · (1 − mean Σp²),  Ht = 1 − Σp̄² + Hs/2kñ,
//  - Nei (1973), uncorrected: Hs = 1 − mean Σp²,  Ht = 1 − Σp̄².
//
//  Raw values are stored; don't change them.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

public extension StructureSpec {

    /// How Hs and Ht, and so Gst, G′st and Dest, are estimated from a locus's allele counts.
    enum Heterozygosity: String, CaseIterable, Identifiable, Codable, Sendable {
        /// Nei & Chesser's (1983) estimates, corrected for sample size and for the heterozygotes observed.
        case neiChesser
        /// Jost's (2008, eq. 12) form of Nei & Chesser's estimates, corrected for sample size alone.
        case jost
        /// Nei's (1973) estimates straight from the allele frequencies, with no correction.
        case uncorrected

        /// The estimator itself.
        public var id: Self { self }

        /// The estimator a new table starts with.
        public static let standard = Heterozygosity.neiChesser

        /// The estimator of tables saved before there was a choice.
        static let earlier = Heterozygosity.jost

        /// The estimator's name in menus.
        public var title: String {
            switch self {
            case .neiChesser: "Nei & Chesser (1983)"
            case .jost: "Jost (2008)"
            case .uncorrected: "Uncorrected (Nei 1973)"
            }
        }

        /// What the estimator does, in a sentence for the controls.
        public var summary: String {
            switch self {
            case .neiChesser:
                "Hs and Ht corrected for sample size and for the heterozygotes observed (Nei & Chesser 1983), as in "
                    + "hierfstat's basic.stats."
            case .jost:
                "Hs and Ht corrected for sample size assuming Hardy–Weinberg within strata, with no observed-"
                    + "heterozygosity term (Jost 2008, eq. 12), as in mmod."
            case .uncorrected:
                "Hs and Ht straight from the allele frequencies (Nei 1973); small samples make Hs low and Gst, G′st "
                    + "and Dest high."
            }
        }

        /// The estimator as the end of a sentence beginning "Hs and Ht are", for legends and Methods.
        var methods: String {
            switch self {
            case .neiChesser:
                "Nei & Chesser's (1983) estimates, corrected for sample size and observed heterozygosity"
            case .jost:
                "Nei & Chesser's (1983) estimates in Jost's (2008, eq. 12) form, corrected for sample size without "
                    + "the observed-heterozygosity term"
            case .uncorrected:
                "Nei's (1973) estimates from the allele frequencies, not corrected for sample size"
            }
        }
    }
}
