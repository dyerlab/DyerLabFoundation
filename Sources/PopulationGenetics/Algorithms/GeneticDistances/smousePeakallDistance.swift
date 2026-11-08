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
//  Created by Rodney Dyer on 2026.06.28.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
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

/// Adds one locus's Smouse–Peakall distances, and a count of the pairs scored, to running totals.
///
/// The totals are upper triangles packed row by row, as ``GeneticDistanceMatrix/init(count:packed:)`` takes
/// them, so the inner loop is a plain walk through two arrays: at real panel sizes (millions of pairs per
/// locus) a subscript per pair costs more than the arithmetic.
///
/// - Parameters:
///   - column: The locus.
///   - distance: The running sum of squared distances.
///   - coverage: The running count of loci at which each pair was scored.
func accumulateDistanceAndCoverage(column: any GenotypeColumn,
                                   distance: inout [Double],
                                   coverage: inout [Double]) {
    let n = column.count
    precondition(distance.count == n * (n - 1) / 2 && coverage.count == distance.count,
                 "accumulateDistanceAndCoverage: totals are the wrong size")
    // Each genotype as two allele indices, 0 where it isn't a complete diploid. Dosages become 1/1, 1/2
    // and 2/2, which give the same (dosage_i − dosage_j)² distances.
    var left = [UInt8](repeating: 0, count: n)
    var right = [UInt8](repeating: 0, count: n)
    let biallelic = column as? BiallelicColumn
    for i in 0..<n {
        if let biallelic {
            guard let dosage = biallelic.dosage(at: i) else { continue }
            (left[i], right[i]) = (dosage > 1 ? 2 : 1, dosage > 0 ? 2 : 1)
        } else if let (a, b) = column.alleles(at: i), a != 0, b != 0 {
            (left[i], right[i]) = (a, b)
        }
    }
    // The inline form of `smousePeakallSquaredDistance`: ½ (Σ c_i² + Σ c_j²) − c_i·c_j.
    left.withUnsafeBufferPointer { left in
        right.withUnsafeBufferPointer { right in
            distance.withUnsafeMutableBufferPointer { total in
                coverage.withUnsafeMutableBufferPointer { covered in
                    var k = 0
                    for i in 0..<n {
                        let a0 = left[i], a1 = right[i]
                        guard a0 != 0 else {
                            k += n - i - 1
                            continue
                        }
                        let squaresA = a0 == a1 ? 4 : 2
                        for j in (i + 1)..<n {
                            let b0 = left[j], b1 = right[j]
                            if b0 != 0 {
                                var dot = 0
                                if a0 == b0 { dot += 1 }
                                if a0 == b1 { dot += 1 }
                                if a1 == b0 { dot += 1 }
                                if a1 == b1 { dot += 1 }
                                total[k] += Double((squaresA + (b0 == b1 ? 4 : 2)) / 2 - dot)
                                covered[k] += 1
                            }
                            k += 1
                        }
                    }
                }
            }
        }
    }
}
