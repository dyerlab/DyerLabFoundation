//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  smousePeakallSquaredDistance.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 6/28/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

/// Smouse–Peakall squared genetic distance between two diploid genotypes at one
/// locus, expressed as allele-index pairs (0 = absent).
///
/// d² = ½ Σ_a (c_ia − c_ja)², where c is the count (0/1/2) of allele `a`. This
/// reproduces the canonical ladder (AA·AA = 0, AA·AB = 1, AA·BB = 4). Returns
/// `nil` if either genotype is not a complete diploid (pairwise-complete).
public func smousePeakallSquaredDistance(_ a: (UInt8, UInt8), _ b: (UInt8, UInt8)) -> Double? {
    guard a.0 != 0, a.1 != 0, b.0 != 0, b.1 != 0 else { return nil }
    var delta: [UInt8: Int] = [:]
    delta[a.0, default: 0] += 1
    delta[a.1, default: 0] += 1
    delta[b.0, default: 0] -= 1
    delta[b.1, default: 0] -= 1
    var sum = 0
    for (_, d) in delta { sum += d * d }
    return Double(sum) / 2.0
}
