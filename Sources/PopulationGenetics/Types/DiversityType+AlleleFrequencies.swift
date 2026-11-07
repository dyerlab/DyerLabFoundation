//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityType+AlleleFrequencies.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

public extension DiversityType {

    /// The metrics computed from one locus's allele counts, which can be read from `AlleleFrequencies`.
    static let frequencyStatistics: [DiversityType] = [.A, .A95, .Ae, .Ho, .He]

    /// Computes the metric for one set of genotypes.
    ///
    /// - Parameter frequencies: The allele counts at one locus.
    /// - Returns: The metric, or `nil` if it isn't one of ``frequencyStatistics`` or no genotype was counted. The
    ///   check matters: with nothing counted `AlleleFrequencies.He` is `1`, which would plot a locus with no data
    ///   as maximally diverse.
    func value(of frequencies: AlleleFrequencies) -> Double? {
        guard frequencies.numGenos > 0 else { return nil }
        switch self {
        case .A: return frequencies.A
        case .A95: return frequencies.A95
        case .Ae: return frequencies.Ae
        case .Ho: return frequencies.Ho
        case .He: return frequencies.He
        case .Undefined, .Ht, .Hi, .Hos, .Hes, .Pe: return nil
        }
    }
}
