//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DistanceSpec+Measure.swift
//  PopulationGenetics
//
//  The distance measures. Great-circle distance is physical and works among
//  individuals or strata. The genetic measures follow gstudio's
//  genetic_distance(): AMOVA and Bray-Curtis among individuals (the inputs of
//  Smouse & Peakall's spatial autocorrelation), and the allele-frequency
//  distances, pairwise Φ_ST, cGD and dcGD among strata. dcGD is the one directed
//  measure: its matrix is asymmetric, from row to column. The raw values are
//  gstudio's `mode` names (lowercased) where it has one, and are part of the file
//  format.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

public extension DistanceSpec {

    /// How the distance between two units is measured.
    enum Measure: String, Codable, CaseIterable, Identifiable, Sendable {
        /// The great-circle distance between coordinates, in kilometres.
        case greatCircle = "great_circle"
        /// Smouse & Peakall's (1999) squared genetic distance between individuals, summed over loci.
        case amova
        /// Bray-Curtis distance between individuals: one minus the proportion of shared alleles (Bowcock et al. 1994).
        case bray
        /// Nei's (1978) unbiased genetic distance between strata.
        case nei
        /// Cavalli-Sforza & Edwards' (1967) chord distance between strata, summed over loci.
        case cavalli
        /// The shared-allele distance between strata, `1 − Ps`.
        case dps
        /// The Euclidean distance between strata's allele frequencies.
        case euclidean
        /// Pairwise Φ_ST: the AMOVA of each pair of strata.
        case phiST = "phi_st"
        /// Conditional genetic distance: the shortest path through the population graph (Dyer & Nason 2004).
        case cgd
        /// Directional conditional genetic distance: each population-graph edge's cGD split into directed shares by
        /// the genetic-gravity neighbourhood weights, then the shortest directed path (Dyer, in review). Asymmetric.
        case dcgd

        /// The measure itself.
        public var id: Self { self }

        /// The measure's name, as the controls and legend show it.
        public var title: String {
            switch self {
            case .greatCircle: "Great-circle distance"
            case .amova: "AMOVA distance"
            case .bray: "Bray-Curtis distance"
            case .nei: "Nei's distance"
            case .cavalli: "Cavalli-Sforza chord distance"
            case .dps: "Shared-allele distance"
            case .euclidean: "Euclidean distance"
            case .phiST: "Pairwise Φ_ST"
            case .cgd: "Conditional genetic distance"
            case .dcgd: "Directional conditional genetic distance"
            }
        }

        /// The measure's short name in a formula, such as `Φ_ST`, `cGD` or `km`.
        public var symbol: String {
            switch self {
            case .greatCircle: "km"
            case .amova: "AMOVA"
            case .bray: "Bray"
            case .nei: "Nei"
            case .cavalli: "Dch"
            case .dps: "Dps"
            case .euclidean: "Euclidean"
            case .phiST: "Φ_ST"
            case .cgd: "cGD"
            case .dcgd: "dcGD"
            }
        }

        /// The units of the distances, or `nil` for a genetic distance, which has none.
        public var units: String? {
            self == .greatCircle ? "km" : nil
        }

        /// Whether the measure compares genotypes rather than locations.
        public var isGenetic: Bool {
            self != .greatCircle
        }

        /// Whether the distance from one unit to another can differ from the distance back, so the matrix is read
        /// from row to column.
        public var isDirected: Bool {
            self == .dcgd
        }

        /// Whether the measure is measured through the population graph, whose strata need at least
        /// ``DistanceAnalysis/minimumGraphStratumSize`` genotyped individuals.
        public var isGraphBased: Bool {
            self == .cgd || self == .dcgd
        }

        /// Whether the measure works among the adults themselves.
        public var isAmongIndividuals: Bool {
            switch self {
            case .greatCircle, .amova, .bray: true
            default: false
            }
        }

        /// Whether the measure works among strata.
        public var isAmongStrata: Bool {
            switch self {
            case .amova, .bray: false
            default: true
            }
        }

        /// How the measure is computed, for the controls, legend and log.
        public var methods: String {
            switch self {
            case .greatCircle:
                "Great-circle distances (km), by the haversine formula on a sphere of radius "
                    + "\(Int(GreatCircle.earthRadius)) km"
            case .amova:
                "AMOVA distances: Smouse & Peakall's (1999) squared distances between genotypes, summed over loci; "
                    + "a pair not genotyped at every locus is scaled up to all of them"
            case .bray:
                "Bray-Curtis distances: one minus the proportion of alleles two individuals share (Bowcock et al. "
                    + "1994), averaged over the loci both are genotyped at"
            case .nei:
                "Nei's (1978) unbiased genetic distance, -ln(Jxy / √(Jx Jy)), with Jx and Jy corrected for "
                    + "sample size and each summed over the loci both strata are genotyped at"
            case .cavalli:
                "Cavalli-Sforza & Edwards' (1967) chord distance, (2/π)√(2(1 − Σ√(px py))), summed over loci"
            case .dps:
                "Shared-allele distances, 1 − Ps, with Ps the sum of the smaller of each allele's two frequencies, "
                    + "averaged over loci"
            case .euclidean:
                "Euclidean distances between the strata's allele frequencies over all loci"
            case .phiST:
                "Pairwise Φ_ST: the AMOVA (Excoffier et al. 1992) of each pair of strata, from Smouse & Peakall's "
                    + "squared distances between genotypes"
            case .cgd:
                "Conditional genetic distances (Dyer & Nason 2004): the shortest path between strata through the "
                    + "population graph, among strata of at least 3 individuals"
            case .dcgd:
                "Directional conditional genetic distances (dcGD; Dyer, in review): each population-graph edge's "
                    + "conditional genetic distance split into two directed shares by the genetic-gravity "
                    + "neighbourhood weights (γ = \(AnalysisReport.number(DistanceAnalysis.defaultGamma))), then the "
                    + "shortest directed path from each stratum to each other, among strata of at least 3 individuals"
            }
        }
    }
}
