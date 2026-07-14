//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  smousePeakallCoverage.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

/// A per-locus "was this pair actually scored" matrix: `1.0` at `(i, j)` when
/// both individuals have a complete diploid call at this locus, `0.0`
/// otherwise. Mirrors `smousePeakallDistance`'s missing/haploid exclusion
/// exactly (a haploid call — one real allele, one absent — counts as
/// unscored here too, matching `smousePeakallSquaredDistance`'s `nil` for
/// any incomplete genotype), so summing coverage matrices across loci gives
/// the true per-pair valid-locus count needed to normalize a summed
/// `GeneticDistanceMatrix` — see `MissingDataStrategy`.
///
/// - Parameter column: The genotype column providing per-individual allele pairs.
/// - Returns: A `GeneticDistanceMatrix` of size `column.count × column.count`
///   holding `1.0`/`0.0` coverage flags rather than distances.
public func smousePeakallCoverage(column: any GenotypeColumn) -> GeneticDistanceMatrix {
    let n = column.count
    var matrix = GeneticDistanceMatrix(count: n)
    let isScored: [Bool] = (0..<n).map { i in
        guard let (a, b) = column.alleles(at: i) else { return false }
        return a != 0 && b != 0
    }
    for i in 0..<n where isScored[i] {
        for j in (i + 1)..<n where isScored[j] {
            matrix[i, j] = 1.0
        }
    }
    return matrix
}
