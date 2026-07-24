//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  OutcrossingResult.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/23/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Foundation

extension Outcrossing {

    /// The retained posterior samples from a ``Sampler`` run, plus summary statistics over them.
    public struct Result: Sendable {

        /// Every retained chain state, oldest first.
        public let samples: [State]

        /// Posterior mean outcrossing rate, averaged across all retained samples.
        public var meanT: Double {
            samples.map(\.t).reduce(0.0, +) / Double(samples.count)
        }

        /// Posterior mean inbreeding coefficient, averaged across every family in every retained sample.
        public var meanF: Double {
            let totalF = samples.flatMap { state in
                state.inbreedingHistories.map { Outcrossing.inbreedingCoefficient(forIH: $0) }
            }
            return totalF.reduce(0.0, +) / Double(totalF.count)
        }

        /// The posterior distribution over inbreeding history categories (`0...6`), as proportions summing to `1`.
        ///
        /// - Returns: Seven proportions, indexed by inbreeding history category.
        public func posteriorIH() -> [Double] {
            var counts = [Int](repeating: 0, count: 7)
            let totalIH = samples.flatMap(\.inbreedingHistories)
            for ih in totalIH {
                counts[ih] += 1
            }
            return counts.map { Double($0) / Double(totalIH.count) }
        }

        /// A percentile credible interval for the outcrossing rate, from the retained samples.
        ///
        /// - Parameter percentile: The interval's width, e.g. `0.95` for a 95% credible interval.
        /// - Returns: The lower and upper bounds of the interval.
        public func credibleIntervalT(percentile: Double = 0.95) -> (Double, Double) {
            let sortedT = samples.map(\.t).sorted()
            let lowerIdx = Int(Double(sortedT.count) * (1.0 - percentile) / 2.0)
            let upperIdx = Int(Double(sortedT.count) * (1.0 + percentile) / 2.0)
            return (sortedT[lowerIdx], sortedT[upperIdx])
        }

        /// A human-readable summary of the posterior: mean `t` and `F`, a 95% credible interval for `t`, and the inbreeding history distribution.
        public func summary() -> String {
            var s = "Outcrossing Analysis Summary\n"
            s += "=======================\n"
            s += String(format: "Mean Outcrossing Rate (t): %.4f\n", meanT)
            let (tLow, tHigh) = credibleIntervalT()
            s += String(format: "95%% Credible Interval (t): [%.4f, %.4f]\n", tLow, tHigh)
            s += String(format: "Mean Inbreeding Coeff (F): %.4f\n", meanF)
            s += "\nPosterior Distribution of Inbreeding History (IH):\n"
            let ihDist = posteriorIH()
            for (ih, prob) in ihDist.enumerated() {
                s += String(format: "  IH %d: %.4f\n", ih, prob)
            }
            return s
        }
    }
}

extension GenotypeMatrix {

    /// Estimates the multilocus population mean outcrossing rate (t_m) and inbreeding coefficient from maternal-family data.
    ///
    /// Runs the ``Outcrossing`` Metropolis-Hastings sampler over every locus
    /// jointly — see ``Outcrossing`` for how this compares to
    /// ``runSingleLocusOutcrossing(design:parameters:hasNullModel:)``.
    ///
    /// - Parameters:
    ///   - design: The maternal families to analyze.
    ///   - parameters: Tuning parameters for the chain; defaults to standard settings.
    ///   - hasNullModel: Per-locus null-allele flags, in ``loci`` order; defaults to no null alleles at any locus.
    /// - Returns: The chain's retained posterior samples and summary statistics.
    public func runOutcrossing(
        design: ParentageDesign,
        parameters: Outcrossing.Parameters = Outcrossing.Parameters(),
        hasNullModel: [Bool]? = nil
    ) -> Outcrossing.Result {
        let sampler = Outcrossing.Sampler(matrix: self, design: design, parameters: parameters, hasNullModel: hasNullModel)
        let samples = sampler.run()
        return Outcrossing.Result(samples: samples)
    }

    /// Estimates the outcrossing rate at a single locus, ignoring every other locus.
    ///
    /// One component of the single-locus outcrossing rate (t_s) — see
    /// ``Outcrossing`` for the distinction from
    /// ``runOutcrossing(design:parameters:hasNullModel:)``'s multilocus t_m.
    /// Most callers want ``runSingleLocusOutcrossing(design:parameters:hasNullModel:)``,
    /// which runs this at every locus.
    ///
    /// - Parameters:
    ///   - locusIndex: The locus to analyze, as an index into ``loci``.
    ///   - design: The maternal families to analyze.
    ///   - parameters: Tuning parameters for the chain; defaults to standard settings.
    ///   - hasNullModel: Per-locus null-allele flags, in ``loci`` order; defaults to no null alleles at any locus.
    /// - Returns: The chain's retained posterior samples and summary statistics, from `locusIndex` alone.
    public func runOutcrossing(
        atLocus locusIndex: Int,
        design: ParentageDesign,
        parameters: Outcrossing.Parameters = Outcrossing.Parameters(),
        hasNullModel: [Bool]? = nil
    ) -> Outcrossing.Result {
        let sampler = Outcrossing.Sampler(matrix: self, design: design, parameters: parameters, hasNullModel: hasNullModel, loci: [locusIndex])
        let samples = sampler.run()
        return Outcrossing.Result(samples: samples)
    }

    /// Estimates the single-locus outcrossing rate (t_s) independently at every locus.
    ///
    /// Average `meanT` across the results for the classic `t_s` summary
    /// statistic, or compare individual loci. See ``Outcrossing`` for how
    /// `t_s` relates to ``runOutcrossing(design:parameters:hasNullModel:)``'s
    /// multilocus `t_m` — `t_m - t_s > 0` is the standard biparental-inbreeding diagnostic.
    ///
    /// - Parameters:
    ///   - design: The maternal families to analyze.
    ///   - parameters: Tuning parameters for the chain; defaults to standard settings.
    ///   - hasNullModel: Per-locus null-allele flags, in ``loci`` order; defaults to no null alleles at any locus.
    /// - Returns: One result per locus, in ``loci`` order.
    public func runSingleLocusOutcrossing(
        design: ParentageDesign,
        parameters: Outcrossing.Parameters = Outcrossing.Parameters(),
        hasNullModel: [Bool]? = nil
    ) -> [Outcrossing.Result] {
        (0..<locusCount).map {
            runOutcrossing(atLocus: $0, design: design, parameters: parameters, hasNullModel: hasNullModel)
        }
    }
}
