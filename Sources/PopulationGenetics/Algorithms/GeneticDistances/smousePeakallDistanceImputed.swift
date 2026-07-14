//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  smousePeakallDistanceImputed.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

/// Smouse–Peakall squared-distance matrix for a single locus, with any
/// missing or haploid genotype's allele-count vector imputed as the locus's
/// expected dosage (`2 × frequency`) under the allele frequencies observed
/// among every other individual at this locus — see
/// `MissingDataStrategy.impute`.
///
/// Unlike `smousePeakallDistance`, no pair is ever excluded: every cell is a
/// real computed value. `column.frequencies()` already excludes missing/
/// haploid individuals when accumulating those reference frequencies, so the
/// imputed value is never influenced by other imputed values.
///
/// - Parameter column: The genotype column providing per-individual allele pairs.
/// - Returns: A `GeneticDistanceMatrix` of size `column.count × column.count`.
public func smousePeakallDistanceImputed(column: any GenotypeColumn) -> GeneticDistanceMatrix {
    let n = column.count

    // Biallelic fast path — same (dosage_i - dosage_j)² reduction as
    // `smousePeakallDistance`'s fast path, which holds whether a dosage is a
    // real integer call or an imputed fractional expectation (the count-vector
    // algebra doesn't care). Avoids the generic path's per-pair `Dictionary`
    // allocation, which is what made this path catastrophically slow at real
    // SNP-panel scale before this fast path existed (see `smousePeakallDistance.swift`).
    if let biallelic = column as? BiallelicColumn {
        let freq = biallelic.frequencies()
        // Allele index 2 = alt, by this codebase's convention (see
        // `BiallelicColumn`). `freq.N == 0` means no individual has real data
        // at this locus at all; fall back to a shared constant so every
        // (missing, missing) pair still gets distance 0, matching the generic
        // path's degenerate "both vectors imputed to `[:]`" behavior exactly.
        let imputedDosage = freq.N > 0 ? 2.0 * freq.frequency(forIndex: 2) : 0.0
        let dosages: [Double] = (0..<n).map { i in
            biallelic.dosage(at: i).map(Double.init) ?? imputedDosage
        }
        var matrix = GeneticDistanceMatrix(count: n)
        for i in 0..<n {
            for j in (i + 1)..<n {
                let delta = dosages[i] - dosages[j]
                matrix[i, j] = delta * delta
            }
        }
        return matrix
    }

    var matrix = GeneticDistanceMatrix(count: n)

    let freq = column.frequencies()
    // Expected allele-count vector for an individual missing at this locus:
    // 2 × frequency per observed allele. Empty when the locus has no real
    // data at all (every vector then imputes to `[:]`, giving distance 0 —
    // "no information" rather than a crash or NaN).
    let expected: [UInt8: Double] = Dictionary(
        uniqueKeysWithValues: freq.observedAlleleIndices.map { ($0, 2.0 * freq.frequency(forIndex: $0)) }
    )

    let vectors: [[UInt8: Double]] = (0..<n).map { i in
        if let (a, b) = column.alleles(at: i), a != 0, b != 0 {
            var v: [UInt8: Double] = [:]
            v[a, default: 0] += 1
            v[b, default: 0] += 1
            return v
        }
        return expected
    }

    for i in 0..<n {
        for j in (i + 1)..<n {
            var delta: [UInt8: Double] = [:]
            for (allele, c) in vectors[i] { delta[allele, default: 0] += c }
            for (allele, c) in vectors[j] { delta[allele, default: 0] -= c }
            matrix[i, j] = delta.values.reduce(0.0) { $0 + $1 * $1 } / 2.0
        }
    }
    return matrix
}

/// Accumulates one locus's imputed contribution directly into a running
/// distance total in a single O(n²) pass, without materializing an
/// intermediate per-locus `GeneticDistanceMatrix` — the `.impute` strategy's
/// counterpart to `accumulateDistanceAndCoverage`. No separate coverage
/// accumulator is needed here: imputation means every pair is scored at
/// every locus, so coverage is uniformly `lociArray.count`.
func accumulateImputedDistance(column: any GenotypeColumn, into distance: inout GeneticDistanceMatrix) {
    let n = column.count

    if let biallelic = column as? BiallelicColumn {
        let freq = biallelic.frequencies()
        let imputedDosage = freq.N > 0 ? 2.0 * freq.frequency(forIndex: 2) : 0.0
        let dosages: [Double] = (0..<n).map { i in
            biallelic.dosage(at: i).map(Double.init) ?? imputedDosage
        }
        for i in 0..<n {
            for j in (i + 1)..<n {
                let delta = dosages[i] - dosages[j]
                distance[i, j] += delta * delta
            }
        }
        return
    }

    let freq = column.frequencies()
    let expected: [UInt8: Double] = Dictionary(
        uniqueKeysWithValues: freq.observedAlleleIndices.map { ($0, 2.0 * freq.frequency(forIndex: $0)) }
    )
    let vectors: [[UInt8: Double]] = (0..<n).map { i in
        if let (a, b) = column.alleles(at: i), a != 0, b != 0 {
            var v: [UInt8: Double] = [:]
            v[a, default: 0] += 1
            v[b, default: 0] += 1
            return v
        }
        return expected
    }

    for i in 0..<n {
        for j in (i + 1)..<n {
            var delta: [UInt8: Double] = [:]
            for (allele, c) in vectors[i] { delta[allele, default: 0] += c }
            for (allele, c) in vectors[j] { delta[allele, default: 0] -= c }
            distance[i, j] += delta.values.reduce(0.0) { $0 + $1 * $1 } / 2.0
        }
    }
}
