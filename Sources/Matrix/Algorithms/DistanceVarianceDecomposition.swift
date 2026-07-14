//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  DistanceVarianceDecomposition.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 6/28/26.
//

import Foundation

/// Distance-based one-level random-effects variance decomposition over a
/// fixed squared-distance matrix — the same computation known as AMOVA in
/// population genetics, or as a distance-based/PERMANOVA-style ANOVA
/// elsewhere. Operates purely on a squared-distance matrix and integer
/// group labels; it has no notion of what the underlying units represent.
public struct DistanceVarianceDecomposition: Sendable {

    /// Number of individuals / analysis units.
    public let unitCount: Int

    /// Squared distances, flattened N×N (symmetric, zero diagonal).
    private let d2: [Double]

    /// Total sum of squares — invariant under permutation, computed once.
    public let totalSS: Double

    /// Builds a decomposition from a symmetric squared-distance matrix.
    ///
    /// - Parameter squaredDistances: N×N matrix of squared distances; the
    ///   diagonal is ignored and the matrix is assumed symmetric.
    public init(squaredDistances: [[Double]]) {
        let n = squaredDistances.count
        self.unitCount = n
        var flat = [Double](repeating: 0.0, count: n * n)
        var sumUpper = 0.0
        for i in 0..<n {
            for j in 0..<n {
                let v = squaredDistances[i][j]
                flat[i * n + j] = v
                if j > i { sumUpper += v }
            }
        }
        self.d2 = flat
        self.totalSS = n > 0 ? sumUpper / Double(n) : 0.0
    }

    /// Within-group sum of squares for a partition.
    ///
    /// - Parameter partition: Group label per individual, length must equal `unitCount`.
    /// - Returns: The within-group sum of squared distances.
    /// - Precondition: `partition.count == unitCount`. This is the sole entry
    ///   point every other partition-taking method (`decompose`,
    ///   `permutationTest`, `permutationProgress`) routes through first, so
    ///   checking here catches a length mismatch before `decompose` could
    ///   otherwise silently compute a group count (`k`) inconsistent with
    ///   what `withinSS` actually grouped.
    public func withinSS(partition: [Int]) -> Double {
        precondition(partition.count == unitCount,
                     "DistanceVarianceDecomposition.withinSS: partition.count (\(partition.count)) must equal unitCount (\(unitCount))")
        let n = unitCount
        var labelToGroup: [Int: Int] = [:]
        var sizes: [Int] = []
        var group = [Int](repeating: 0, count: n)
        for i in 0..<n {
            let label = partition[i]
            if let g = labelToGroup[label] {
                group[i] = g
            } else {
                let g = sizes.count
                labelToGroup[label] = g
                sizes.append(0)
                group[i] = g
            }
            sizes[group[i]] += 1
        }
        var groupSum = [Double](repeating: 0.0, count: sizes.count)
        for i in 0..<n {
            let gi = group[i]
            let base = i * n
            for j in (i + 1)..<n where group[j] == gi {
                groupSum[gi] += d2[base + j]
            }
        }
        var ss = 0.0
        for k in 0..<sizes.count where sizes[k] > 0 {
            ss += groupSum[k] / Double(sizes[k])
        }
        return ss
    }

    /// Full one-level variance decomposition for a partition.
    ///
    /// - Parameter partition: Group label per individual, length must equal `unitCount`.
    /// - Returns: A `DistanceVarianceDecompositionResult` with SS components and variance estimates.
    public func decompose(partition: [Int]) -> DistanceVarianceDecompositionResult {
        let n = unitCount
        let withinSS = withinSS(partition: partition)
        let amongSS = totalSS - withinSS

        var sizeByLabel: [Int: Int] = [:]
        for label in partition { sizeByLabel[label, default: 0] += 1 }
        let sizes = Array(sizeByLabel.values)
        let k = sizes.count

        let dfAmong = k - 1
        let dfWithin = n - k

        guard dfAmong > 0, dfWithin > 0 else {
            return DistanceVarianceDecompositionResult(totalSS: totalSS, withinSS: withinSS, amongSS: amongSS,
                               groupCount: k, dfAmong: dfAmong, dfWithin: dfWithin,
                               sigmaAmong: 0.0, sigmaWithin: withinSS / Double(max(dfWithin, 1)),
                               varianceRatio: 0.0)
        }

        let msAmong = amongSS / Double(dfAmong)
        let msWithin = withinSS / Double(dfWithin)

        let sumSqSizes = sizes.reduce(0.0) { $0 + Double($1 * $1) }
        let n0 = (Double(n) - sumSqSizes / Double(n)) / Double(dfAmong)

        let sigmaWithin = msWithin
        let sigmaAmong = n0 > 0 ? (msAmong - msWithin) / n0 : 0.0
        let denom = sigmaAmong + sigmaWithin
        let ratio = denom != 0 ? sigmaAmong / denom : 0.0

        return DistanceVarianceDecompositionResult(totalSS: totalSS, withinSS: withinSS, amongSS: amongSS,
                           groupCount: k, dfAmong: dfAmong, dfWithin: dfWithin,
                           sigmaAmong: sigmaAmong, sigmaWithin: sigmaWithin, varianceRatio: ratio)
    }

    /// Permutation test for the variance ratio: shuffles group labels
    /// (preserving group sizes), recomputing only the within-group SS each
    /// iteration. The p-value isn't precomputed here — call
    /// `pValue(direction:)` on the returned result, which defaults to
    /// `.greaterOrEqual` (the standard one-sided "is the ratio unusually
    /// large" test) but also supports `.lessOrEqual`/`.notEqualTo`.
    ///
    /// - Parameters:
    ///   - partition: observed group label per unit.
    ///   - iterations: number of permutations.
    ///   - seed: PRNG seed for reproducibility.
    ///   - tag: which analysis this is — e.g. a caller's own `.amovaPhiST`
    ///     or `.weirCockerhamTheta`; this type has no opinion on the name.
    public func permutationTest(partition: [Int], iterations: Int, seed: UInt64, tag: AnalysisTag) -> NullDistributionResult {
        Resampling.permutationTest(labels: partition, iterations: iterations, seed: seed, tag: tag) { labels in
            self.decompose(partition: labels).varianceRatio
        }
    }
}


// MARK: - Streaming permutation (live convergence)

extension DistanceVarianceDecomposition {

    /// Streams a permutation test, emitting a progress snapshot every `emitEvery`
    /// permutations (and a final one at completion). The same `seed` reproduces
    /// the same sequence and final p-value as `permutationTest`.
    ///
    /// Work runs in a cancellable child task; ending iteration of the stream
    /// cancels it.
    public func permutationProgress(partition: [Int], iterations: Int, seed: UInt64,
                                    emitEvery: Int = 1) -> AsyncStream<DistanceVarianceDecompositionProgress> {
        AsyncStream { continuation in
            guard iterations > 0 else { continuation.finish(); return }
            let step = max(emitEvery, 1)
            let task = Task {
                let observed = decompose(partition: partition).varianceRatio
                var rng = SplitMix64(seed: seed)
                var labels = partition
                var exceedances = 0
                var sumRatio = 0.0
                for i in 1...iterations {
                    if Task.isCancelled { break }
                    labels.shuffle(using: &rng)
                    let ratio = decompose(partition: labels).varianceRatio
                    if ratio >= observed { exceedances += 1 }
                    sumRatio += ratio
                    if i % step == 0 || i == iterations {
                        continuation.yield(DistanceVarianceDecompositionProgress(
                            iteration: i, observedRatio: observed, exceedances: exceedances,
                            lastRatio: ratio, runningMeanRatio: sumRatio / Double(i)))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
