//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMatrix+GeneticDistance.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 6/28/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

extension GenotypeMatrix {

    /// Smouse–Peakall squared-distance matrix for a single locus. A pair with
    /// a missing/haploid call at this locus is simply excluded (left at
    /// `0.0`) — unambiguous for one locus, but see `MissingDataStrategy` for
    /// why summing several loci's worth of this isn't.
    public func locusDistance(atLocus locusIndex: Int) -> GeneticDistanceMatrix {
        smousePeakallDistance(column: columns[locusIndex])
    }

    /// Total Smouse–Peakall squared distance over a set of loci.
    ///
    /// - Parameters:
    ///   - loci: Locus ordinals to include.
    ///   - strategy: How to handle pairs not scored at every locus in `loci`
    ///     — see `MissingDataStrategy`. Defaults to `.rescaleToTotalLoci`,
    ///     which reduces to a plain unnormalized sum whenever no pair has any
    ///     missing data (the common case for a mostly-complete panel).
    public func geneticDistance<Loci: Sequence>(
        overLoci loci: Loci, strategy: MissingDataStrategy = .rescaleToTotalLoci
    ) -> GeneticDistanceMatrix
    where Loci.Element == Int {
        let lociArray = Array(loci)

        if strategy == .impute {
            var total = GeneticDistanceMatrix(count: individualCount)
            for j in lociArray { accumulateImputedDistance(column: columns[j], into: &total) }
            return total
        }

        var total = GeneticDistanceMatrix(count: individualCount)
        var covered = GeneticDistanceMatrix(count: individualCount)
        for j in lociArray {
            accumulateDistanceAndCoverage(column: columns[j], distance: &total, coverage: &covered)
        }

        let scale = strategy == .rescaleToTotalLoci ? Double(lociArray.count) : 1.0
        var result = GeneticDistanceMatrix(count: individualCount)
        for i in 0..<individualCount {
            for j in (i + 1)..<individualCount {
                let n = covered[i, j]
                guard n > 0 else { continue } // never jointly scored — leave at 0, not NaN
                result[i, j] = (total[i, j] / n) * scale
            }
        }
        return result
    }

    /// Total Smouse–Peakall squared distance over all loci.
    ///
    /// - Parameter strategy: How to handle pairs not scored at every locus —
    ///   see `MissingDataStrategy`. Defaults to `.rescaleToTotalLoci`.
    public func geneticDistance(strategy: MissingDataStrategy = .rescaleToTotalLoci) -> GeneticDistanceMatrix {
        geneticDistance(overLoci: 0..<locusCount, strategy: strategy)
    }
}
