//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  smousePeakallDistance.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 6/28/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

/// Smouse–Peakall squared-distance matrix for a single locus column.
///
/// - Parameter column: The genotype column providing per-individual allele pairs.
/// - Returns: A `GeneticDistanceMatrix` of size `column.count × column.count`.
public func smousePeakallDistance(column: any GenotypeColumn) -> GeneticDistanceMatrix {
    let n = column.count

    // Biallelic fast path. For exactly 2 allele slots, d² = ½Σ_a(c_ia-c_ja)²
    // algebraically reduces to (dosage_i - dosage_j)² (dosage = alt-allele
    // count, 0/1/2) — verified against the canonical ladder in
    // `GeneticDistanceTests.canonicalLadder`. This avoids the generic path's
    // per-pair `Dictionary` allocation in `smousePeakallSquaredDistance`,
    // which dominates runtime at real SNP-panel scale: a 1318-individual x
    // 926-locus panel is ~800M pairs, each allocating a `[UInt8: Int]` in the
    // generic path — measured at over 8 minutes before this fast path existed.
    if let biallelic = column as? BiallelicColumn {
        var matrix = GeneticDistanceMatrix(count: n)
        let dosages: [UInt8?] = (0..<n).map { biallelic.dosage(at: $0) }
        for i in 0..<n {
            guard let di = dosages[i] else { continue }
            for j in (i + 1)..<n {
                guard let dj = dosages[j] else { continue }
                let delta = Int(di) - Int(dj)
                matrix[i, j] = Double(delta * delta)
            }
        }
        return matrix
    }

    var matrix = GeneticDistanceMatrix(count: n)
    let genotypes: [(UInt8, UInt8)?] = (0..<n).map { column.alleles(at: $0) }
    for i in 0..<n {
        guard let gi = genotypes[i] else { continue }
        for j in (i + 1)..<n {
            guard let gj = genotypes[j], let d = smousePeakallSquaredDistance(gi, gj) else { continue }
            matrix[i, j] = d
        }
    }
    return matrix
}

/// Accumulates one locus's contribution into running distance and coverage
/// totals in a single O(n²) pass, without allocating an intermediate
/// per-locus `GeneticDistanceMatrix`. `geneticDistance(overLoci:strategy:)`'s
/// hot path — computing `smousePeakallDistance`/`smousePeakallCoverage` and
/// `add()`-ing each into a running total materializes (and immediately
/// discards) two fresh matrices *per locus*, which for a real SNP-panel-scale
/// dataset (hundreds of loci, each a several-MB allocation for a
/// thousand-plus-individual panel) dominates runtime far more than the
/// per-pair arithmetic itself does.
func accumulateDistanceAndCoverage(column: any GenotypeColumn,
                                    distance: inout GeneticDistanceMatrix,
                                    coverage: inout GeneticDistanceMatrix) {
    let n = column.count

    if let biallelic = column as? BiallelicColumn {
        let dosages: [UInt8?] = (0..<n).map { biallelic.dosage(at: $0) }
        for i in 0..<n {
            guard let di = dosages[i] else { continue }
            for j in (i + 1)..<n {
                guard let dj = dosages[j] else { continue }
                let delta = Int(di) - Int(dj)
                distance[i, j] += Double(delta * delta)
                coverage[i, j] += 1.0
            }
        }
        return
    }

    let genotypes: [(UInt8, UInt8)?] = (0..<n).map { column.alleles(at: $0) }
    for i in 0..<n {
        guard let gi = genotypes[i] else { continue }
        for j in (i + 1)..<n {
            guard let gj = genotypes[j], let d = smousePeakallSquaredDistance(gi, gj) else { continue }
            distance[i, j] += d
            coverage[i, j] += 1.0
        }
    }
}
