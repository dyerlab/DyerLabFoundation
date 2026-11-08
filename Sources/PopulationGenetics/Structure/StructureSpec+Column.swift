//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureSpec+Column.swift
//  PopulationGenetics
//
//  The statistics a by-locus table can show. Each is a ratio whose numerator
//  and denominator are summed over loci for the multilocus row. Raw values are
//  stored; don't change them.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

public extension StructureSpec {

    /// A statistic column of a by-locus table.
    enum Column: String, CaseIterable, Identifiable, Codable, Sendable {
        /// Weir & Cockerham's θ.
        case theta
        /// Weir & Cockerham's F_IS.
        case fIS
        /// Weir & Cockerham's F_IT.
        case fIT
        /// Φ_ST from gene copies.
        case phiGeneCopies
        /// Φ_ST from genotypes.
        case phiGenotypes
        /// Φ_ST from paternal gametes.
        case phiGametes
        /// Nei's Gst.
        case gst
        /// Hedrick's G′st.
        case gstPrime
        /// Jost's D.
        case dest

        /// The column itself.
        public var id: Self { self }

        /// The columns a sample offers, in table order.
        ///
        /// - Parameter sample: Whose genotypes are analysed.
        /// - Returns: The choices.
        public static func choices(for sample: Sample) -> [Column] {
            sample == .adults ? [.theta, .fIS, .fIT, .phiGeneCopies, .phiGenotypes, .gst, .gstPrime, .dest]
                : [.phiGametes]
        }

        /// The columns a by-locus table starts with.
        ///
        /// - Parameter sample: Whose genotypes are analysed.
        /// - Returns: The defaults.
        public static func defaults(for sample: Sample) -> [Column] {
            sample == .adults ? [.theta, .phiGeneCopies, .gst, .gstPrime, .dest] : [.phiGametes]
        }

        /// The column's header.
        public var header: String {
            switch self {
            case .theta: "θ"
            case .fIS: "F_IS"
            case .fIT: "F_IT"
            case .phiGeneCopies, .phiGametes: "Φ_ST"
            case .phiGenotypes: "Φ_ST (genotypes)"
            case .gst: "Gst"
            case .gstPrime: "G′st"
            case .dest: "Dest"
            }
        }

        /// The column's name in the stored table, a valid R name.
        public var name: String {
            switch self {
            case .theta: "theta"
            case .fIS: "F_IS"
            case .fIT: "F_IT"
            case .phiGeneCopies, .phiGametes: "Phi_ST"
            case .phiGenotypes: "Phi_ST_genotypes"
            case .gst: "Gst"
            case .gstPrime: "Gst_prime"
            case .dest: "Dest"
            }
        }

        /// The column's name in menus.
        public var title: String {
            switch self {
            case .theta: "θ (Weir & Cockerham)"
            case .fIS: "F_IS (Weir & Cockerham)"
            case .fIT: "F_IT (Weir & Cockerham)"
            case .phiGeneCopies: "Φ_ST from gene copies"
            case .phiGenotypes: "Φ_ST from genotypes"
            case .phiGametes: "Φ_ST from paternal gametes"
            case .gst: "Gst (Nei 1973)"
            case .gstPrime: "G′st (Hedrick 2005)"
            case .dest: "Dest (Jost 2008)"
            }
        }

        /// Whether permuting units among strata tests the column. F_IS and F_IT describe individuals, which the
        /// permutation keeps whole, so they aren't tested.
        public var isTestable: Bool { self != .fIS && self != .fIT }

        /// The column's definition, for legends and Methods.
        var definition: String {
            switch self {
            case .theta: "θ is Weir & Cockerham's (1984) estimator"
            case .fIS: "F_IS is the inbreeding of individuals within strata (Weir & Cockerham 1984)"
            case .fIT: "F_IT is the inbreeding of individuals over all strata (Weir & Cockerham 1984)"
            case .phiGeneCopies: "Φ_ST is from an AMOVA of gene copies"
            case .phiGenotypes: "Φ_ST (genotypes) is from an AMOVA of individuals with Smouse & Peakall's (1999) "
                + "distances"
            case .phiGametes: "Φ_ST is from an AMOVA of paternal gametes (2Gener; Smouse et al. 2001)"
            case .gst: "Gst = (Ht − Hs)/Ht (Nei 1973)"
            case .gstPrime: "G′st = Gst(k − 1 + Hs)/((k − 1)(1 − Hs)) for k strata (Hedrick 2005)"
            case .dest: "Dest = (Ht − Hs)/(1 − Hs) · k/(k − 1) (Jost 2008)"
            }
        }
    }
}
