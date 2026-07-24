//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  OutcrossingSampler.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/23/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Foundation
import Matrix

extension Outcrossing {

    /// Tuning knobs for a ``Sampler`` run.
    public struct Parameters: Sendable {

        /// Total number of MCMC steps.
        public var numSteps: Int = 100_000

        /// Number of leading steps discarded before any samples are retained.
        public var burnIn: Int = 10_000

        /// Retain a posterior sample (and re-propose the allele frequencies)
        /// every `thinning` steps past `burnIn`.
        public var thinning: Int = 10

        /// Half-width of the symmetric random-walk proposal for the outcrossing rate `t`.
        public var tTuning: Double = 0.05

        /// Half-width of the symmetric random-walk proposal for an allele's unnormalized weight (y-value).
        public var afTuning: Double = 0.1

        /// Starting value for the outcrossing rate `t`.
        public var initialT: Double = 0.5

        /// Seed for the chain's pseudo-random number generator, so runs are reproducible.
        public var seed: UInt64 = 0

        /// Creates a parameter set using Outcrossing's defaults.
        public init() {}
    }

    /// One posterior draw from the chain: the outcrossing rate, every
    /// family's inbreeding history, and the allele frequencies and maternal
    /// genotypes that produced it.
    public struct State: Sendable {

        /// Population mean outcrossing rate.
        public var t: Double

        /// Inbreeding history category (`0...6`) for each family, in ``ParentageDesign/families`` order.
        public var inbreedingHistories: [Int]

        /// Unnormalized allele weights driving ``alleleFrequencies``, indexed `[locus][allele]`.
        ///
        /// These persist across steps and are only perturbed one allele at a
        /// time (see ``Sampler/updateAlleleFrequencies()``); ``alleleFrequencies``
        /// is their renormalization and is what the likelihood actually reads.
        public var yValues: [[Double]]

        /// Population allele frequencies, indexed `[locus][allele]`. Index `0` is the null-allele frequency.
        public var alleleFrequencies: [[Double]]

        /// Each family's maternal genotype, indexed `[family][locus]`.
        public var maternalGenotypes: [[(UInt8, UInt8)]]
    }

    /// A Metropolis-Hastings sampler estimating the joint posterior of
    /// population outcrossing rate, per-family inbreeding history,
    /// population allele frequencies, and maternal genotypes, from a
    /// maternal-family genotype matrix.
    ///
    /// By default estimates the multilocus rate `t_m` from every locus
    /// jointly; restrict ``activeLoci`` (via the `loci:` initializer
    /// parameter) to a single locus for a `t_s` component. See ``Outcrossing``.
    ///
    /// Construct with ``init(matrix:design:parameters:hasNullModel:loci:)``
    /// and call ``run()``; most callers instead go through
    /// ``GenotypeMatrix/runOutcrossing(design:parameters:hasNullModel:)`` or
    /// ``GenotypeMatrix/runSingleLocusOutcrossing(design:parameters:hasNullModel:)``,
    /// which wrap both steps.
    public final class Sampler {

        /// The genotype matrix being analyzed.
        let matrix: GenotypeMatrix

        /// The maternal-family sampling design.
        let design: ParentageDesign

        /// The chain's tuning parameters.
        let parameters: Parameters

        /// Per-locus flag: whether that locus is modeled with a null allele.
        let hasNullModel: [Bool]

        /// The locus indices this sampler estimates `t` from, in ``GenotypeMatrix/loci`` order.
        ///
        /// Every locus by default — the multilocus rate, `t_m`. A single
        /// locus index restricts the whole chain (likelihoods, the allele
        /// frequency update, and maternal genotype imputation) to that locus
        /// alone, which is how ``GenotypeMatrix/runSingleLocusOutcrossing(design:parameters:hasNullModel:)``
        /// estimates `t_s`.
        let activeLoci: [Int]

        /// Per family, the locus indices whose maternal genotype was never observed.
        private var imputedLoci: [[Int]] = []

        /// Per family, the locus indices where the mother was observed as a
        /// homozygote at a null-modeled locus — ambiguous with a null heterozygote.
        private var observedImputedLoci: [[Int]] = []

        /// The chain's current state.
        var currentState: State

        /// The chain's pseudo-random number generator, seeded from ``Parameters/seed``.
        var rng: SplitMix64

        /// Creates a sampler over `matrix` for the given maternal-family design.
        ///
        /// Maternal genotypes are seeded here: an observed, unambiguous
        /// genotype is used as-is; an observed homozygote at a null-modeled
        /// locus is flagged as possibly a masked null heterozygote; and a
        /// genotype with no maternal tissue is imputed by searching for an
        /// allele pair consistent with every offspring's genotype at that
        /// locus. Both flagged cases are then refined by the chain via
        /// ``updateMaternalGenotypes()``.
        ///
        /// - Parameters:
        ///   - matrix: The genotype matrix supplying both maternal and offspring genotypes.
        ///   - design: The maternal families to analyze.
        ///   - parameters: Tuning parameters for the chain.
        ///   - hasNullModel: Per-locus null-allele flags, in ``GenotypeMatrix/loci`` order; defaults to no null alleles at any locus.
        ///   - loci: Locus indices to estimate `t` from; defaults to every locus (`t_m`). Pass a single locus index for a `t_s` component.
        public init(matrix: GenotypeMatrix, design: ParentageDesign, parameters: Parameters = Parameters(), hasNullModel: [Bool]? = nil, loci: [Int]? = nil) {
            self.matrix = matrix
            self.design = design
            self.parameters = parameters
            self.hasNullModel = hasNullModel ?? [Bool](repeating: false, count: matrix.locusCount)
            self.activeLoci = loci ?? Array(0..<matrix.locusCount)
            self.rng = SplitMix64(seed: parameters.seed)
            let activeLociSet = Set(self.activeLoci)

            var initialY = [[Double]]()
            var initialAF = [[Double]]()
            for j in 0..<matrix.locusCount {
                let codebook = matrix.columns[j].codebook
                let count = codebook.count
                initialY.append([Double](repeating: 1.0, count: count))
                initialAF.append([Double](repeating: 1.0 / Double(count), count: count))
            }

            var initialMoms = [[(UInt8, UInt8)]]()
            self.imputedLoci = [[Int]](repeating: [], count: design.families.count)
            self.observedImputedLoci = [[Int]](repeating: [], count: design.families.count)

            for (i, fam) in design.families.enumerated() {
                var momGenos = [(UInt8, UInt8)]()
                for j in 0..<matrix.locusCount {
                    let column = matrix.columns[j]
                    if let momIdx = fam.mother, !column.isEmpty(at: momIdx) {
                        let alleles = column.alleles(at: momIdx)!
                        momGenos.append(alleles)

                        // If it's a homozygote and we have a null model, it's observed-imputed.
                        // Only worth refining via MCMC moves at a locus this sampler actually uses.
                        if self.hasNullModel[j] && alleles.0 == alleles.1 && activeLociSet.contains(j) {
                            self.observedImputedLoci[i].append(j)
                        }
                    } else {
                        // Missing or no maternal tissue: fully imputed. Seed with an
                        // allele pair actually consistent with the offspring, so the
                        // chain doesn't start the family stuck at -infinity log-likelihood.
                        if activeLociSet.contains(j) {
                            self.imputedLoci[i].append(j)
                        }
                        momGenos.append(Self.feasibleMaternalGenotype(
                            column: column,
                            offspring: fam.offspring,
                            hasNullModel: self.hasNullModel[j]
                        ))
                    }
                }
                initialMoms.append(momGenos)
            }

            self.currentState = State(
                t: parameters.initialT,
                inbreedingHistories: [Int](repeating: 0, count: design.families.count),
                yValues: initialY,
                alleleFrequencies: initialAF,
                maternalGenotypes: initialMoms
            )
        }

        /// Runs the chain for ``Parameters/numSteps``, returning every
        /// retained posterior sample.
        ///
        /// Each step updates, in order: the outcrossing rate, every family's
        /// inbreeding history, (every ``Parameters/thinning`` steps) the
        /// allele frequencies, and one imputed maternal genotype per family.
        /// A sample is retained once every ``Parameters/thinning`` steps
        /// past ``Parameters/burnIn``.
        ///
        /// - Returns: The retained chain states, oldest first.
        public func run() -> [State] {
            let retainedCount = max(0, (parameters.numSteps - parameters.burnIn) / parameters.thinning)
            var samples = [State]()
            samples.reserveCapacity(retainedCount)

            guard parameters.numSteps > 0 else { return samples }

            for step in 1...parameters.numSteps {
                updateOutcrossingRate()
                updateInbreedingHistories()
                if step % parameters.thinning == 0 {
                    updateAlleleFrequencies()
                }
                updateMaternalGenotypes()

                if step > parameters.burnIn && step % parameters.thinning == 0 {
                    samples.append(currentState)
                }
            }
            return samples
        }

        // MARK: - Log-likelihood

        /// Log-likelihood of one family's maternal genotype alone, under
        /// Hardy-Weinberg equilibrium with her inbreeding coefficient.
        ///
        /// Used by ``updateInbreedingHistories()``: a family's inbreeding
        /// history only affects how likely her *realized* genotype is under
        /// `F`, not how she transmits it to offspring.
        func motherLogLikelihood(familyIndex: Int, state: State) -> Double {
            let F = Outcrossing.inbreedingCoefficient(forIH: state.inbreedingHistories[familyIndex])
            var logLikelihood = 0.0
            for j in activeLoci {
                let p = Outcrossing.probabilityOfMother(
                    state.maternalGenotypes[familyIndex][j],
                    frequencies: state.alleleFrequencies[j],
                    inbreedingCoefficient: F
                )
                logLikelihood += log(p)
            }
            return logLikelihood
        }

        /// Log-likelihood of one family's offspring alone, given her
        /// (realized, not F-weighted) maternal genotype and the population
        /// outcrossing rate.
        ///
        /// Used by ``updateMaternalGenotypes()``: judging a candidate
        /// maternal genotype by how well it explains the offspring, not by
        /// its own prior probability (which the proposal itself already
        /// draws from), avoids double-counting that prior.
        ///
        /// The mixture over selfing/outcrossing is taken per offspring,
        /// after multiplying single-locus probabilities across every locus —
        /// see ``Outcrossing/probabilityOfOffspringGivenSelfing(_:givenMother:hasNullModel:)``.
        func progenyLogLikelihood(familyIndex: Int, state: State) -> Double {
            let family = design.families[familyIndex]
            let t = state.t
            var logLikelihood = 0.0

            for offspringOrdinal in family.offspring {
                var selfingProb = 1.0
                var outcrossingProb = 1.0
                for j in activeLoci {
                    guard let offspringAlleles = matrix.columns[j].alleles(at: offspringOrdinal) else {
                        continue // Missing data at this locus: no contribution (probability 1.0).
                    }
                    let mother = state.maternalGenotypes[familyIndex][j]
                    selfingProb *= Outcrossing.probabilityOfOffspringGivenSelfing(
                        offspringAlleles, givenMother: mother, hasNullModel: hasNullModel[j]
                    )
                    outcrossingProb *= Outcrossing.probabilityOfOffspringGivenOutcrossing(
                        offspringAlleles, givenMother: mother, frequencies: state.alleleFrequencies[j], hasNullModel: hasNullModel[j]
                    )
                }
                let offspringProb = (1.0 - t) * selfingProb + t * outcrossingProb
                logLikelihood += log(offspringProb)
            }
            return logLikelihood
        }

        /// Log-likelihood of one family (mother and offspring together).
        func familyLogLikelihood(familyIndex: Int, state: State) -> Double {
            motherLogLikelihood(familyIndex: familyIndex, state: state) + progenyLogLikelihood(familyIndex: familyIndex, state: state)
        }

        /// Log-likelihood of the whole population: every family's likelihood, summed.
        func populationLogLikelihood(state: State) -> Double {
            var total = 0.0
            for i in 0..<design.families.count {
                total += familyLogLikelihood(familyIndex: i, state: state)
            }
            return total
        }

        // MARK: - Parameter updates

        /// Metropolis step for the outcrossing rate `t`: a symmetric
        /// random-walk proposal reflected back into `0...1` at either
        /// boundary, accepted against the whole population's log-likelihood.
        func updateOutcrossingRate() {
            let currentLnL = populationLogLikelihood(state: currentState)

            var proposedT = currentState.t + (Double.random(in: 0..<1, using: &rng) - 0.5) * parameters.tTuning
            if proposedT < 0.0 { proposedT = -proposedT }
            if proposedT > 1.0 { proposedT = 2.0 - proposedT }

            var proposedState = currentState
            proposedState.t = proposedT
            let proposedLnL = populationLogLikelihood(state: proposedState)

            guard proposedLnL.isFinite else { return } // Reject: impossible under the proposed t.

            let ratio = proposedLnL - currentLnL
            if ratio > 0 || Double.random(in: 0..<1, using: &rng) < exp(ratio) {
                currentState.t = proposedT
            }
        }

        /// Metropolis step for every family's inbreeding history: draws a
        /// candidate category from the geometric distribution implied by
        /// the current `t`, accepted against that family's maternal
        /// genotype likelihood alone.
        func updateInbreedingHistories() {
            let categoryProbabilities = Self.inbreedingHistoryCategoryProbabilities(t: currentState.t)

            for i in 0..<design.families.count {
                let previousIH = currentState.inbreedingHistories[i]
                let currentLnL = motherLogLikelihood(familyIndex: i, state: currentState)

                let proposedIH = Self.sampleCategory(categoryProbabilities, using: &rng)

                var proposedState = currentState
                proposedState.inbreedingHistories[i] = proposedIH
                let proposedLnL = motherLogLikelihood(familyIndex: i, state: proposedState)

                guard proposedLnL.isFinite else { continue } // Reject: impossible genotype under the proposed F.

                let ratio = proposedLnL - currentLnL
                if ratio > 0 || Double.random(in: 0..<1, using: &rng) < exp(ratio) {
                    currentState.inbreedingHistories[i] = proposedIH
                } else {
                    currentState.inbreedingHistories[i] = previousIH
                }
            }
        }

        /// Metropolis step for population allele frequencies: perturbs one
        /// randomly chosen allele's unnormalized weight (y-value) per
        /// locus, renormalizes that locus's frequencies, and accepts
        /// against the whole population's log-likelihood with the
        /// Hastings correction for the y-to-frequency reparameterization.
        func updateAlleleFrequencies() {
            for j in activeLoci {
                let startIndex = hasNullModel[j] ? 0 : 1
                let numAlleles = currentState.yValues[j].count
                guard numAlleles > startIndex else { continue }

                let chosenAllele = Int.random(in: startIndex..<numAlleles, using: &rng)
                let previousY = currentState.yValues[j][chosenAllele]
                let currentLnL = populationLogLikelihood(state: currentState)

                var proposedY = previousY + (Double.random(in: 0..<1, using: &rng) - 0.5) * parameters.afTuning
                if proposedY < 0.0 { proposedY = -proposedY }

                var proposedState = currentState
                proposedState.yValues[j][chosenAllele] = proposedY

                let sumY = (startIndex..<numAlleles).reduce(0.0) { $0 + proposedState.yValues[j][$1] }
                var proposedFrequencies = [Double](repeating: 0.0, count: numAlleles)
                for allele in startIndex..<numAlleles {
                    proposedFrequencies[allele] = proposedState.yValues[j][allele] / sumY
                }
                proposedState.alleleFrequencies[j] = proposedFrequencies

                let proposedLnL = populationLogLikelihood(state: proposedState)
                guard proposedLnL.isFinite else { continue } // Reject: impossible under the proposed frequencies.

                let acceptanceRatio = exp(proposedLnL - currentLnL) * exp(previousY - proposedY)
                if acceptanceRatio > 1.0 || Double.random(in: 0..<1, using: &rng) < acceptanceRatio {
                    currentState = proposedState
                }
            }
        }

        /// Metropolis step for maternal genotypes: for each family with any
        /// imputed locus, proposes a new genotype at one randomly chosen
        /// such locus and accepts against that family's offspring
        /// log-likelihood alone (see ``progenyLogLikelihood(familyIndex:state:)``).
        func updateMaternalGenotypes() {
            for i in 0..<design.families.count {
                let imputed = imputedLoci[i]
                let observedImputed = observedImputedLoci[i]
                let totalCount = imputed.count + observedImputed.count
                guard totalCount > 0 else { continue }

                let choice = Int.random(in: 0..<totalCount, using: &rng)
                let locusIndex: Int
                let isObservedImputed: Bool
                if choice < imputed.count {
                    locusIndex = imputed[choice]
                    isObservedImputed = false
                } else {
                    locusIndex = observedImputed[choice - imputed.count]
                    isObservedImputed = true
                }

                let previousGenotype = currentState.maternalGenotypes[i][locusIndex]
                let currentLnL = progenyLogLikelihood(familyIndex: i, state: currentState)

                let F = Outcrossing.inbreedingCoefficient(forIH: currentState.inbreedingHistories[i])
                let frequencies = currentState.alleleFrequencies[locusIndex]
                let proposedGenotype = proposeMaternalGenotype(
                    current: previousGenotype,
                    isObservedImputed: isObservedImputed,
                    frequencies: frequencies,
                    inbreedingCoefficient: F,
                    hasNullModel: hasNullModel[locusIndex]
                )

                var proposedState = currentState
                proposedState.maternalGenotypes[i][locusIndex] = proposedGenotype
                let proposedLnL = progenyLogLikelihood(familyIndex: i, state: proposedState)

                guard proposedLnL.isFinite else { continue } // Reject: impossible given the offspring.

                let ratio = proposedLnL - currentLnL
                if ratio > 0 || Double.random(in: 0..<1, using: &rng) < exp(ratio) {
                    currentState.maternalGenotypes[i][locusIndex] = proposedGenotype
                }
            }
        }

        // MARK: - Proposal mechanics

        /// Proposes a candidate maternal genotype at one locus.
        ///
        /// - An observed-imputed locus (a homozygote at a null-modeled
        ///   locus) is a two-state flip between that homozygote and its
        ///   null-heterozygote alternative, weighted by their relative
        ///   probability under Hardy-Weinberg with inbreeding.
        /// - A fully imputed locus draws both alleles from the current
        ///   allele frequencies, with the second allele identical to the
        ///   first with probability `F` (selfing-equilibrium homozygosity).
        private func proposeMaternalGenotype(
            current: (UInt8, UInt8),
            isObservedImputed: Bool,
            frequencies: [Double],
            inbreedingCoefficient F: Double,
            hasNullModel: Bool
        ) -> (UInt8, UInt8) {
            if isObservedImputed {
                let observedAllele = current.1 // The non-null allele.
                let pNull = frequencies[0]
                let pObserved = frequencies[Int(observedAllele)]
                let r = Double.random(in: 0..<1, using: &rng)

                if current.0 == current.1 { // Currently the homozygote: might flip to the null heterozygote.
                    let nullHetProbability = (1.0 - F) * (2.0 * pObserved * pNull)
                    return (r < nullHetProbability) ? (0, observedAllele) : (observedAllele, observedAllele)
                } else { // Currently the null heterozygote: might flip to the homozygote.
                    let homozygoteProbability = (1.0 - F) * (pObserved * pObserved) + (F * pObserved)
                    return (r < homozygoteProbability) ? (observedAllele, observedAllele) : (0, observedAllele)
                }
            } else {
                let startIndex = hasNullModel ? 0 : 1
                let first = sampleAllele(frequencies: frequencies, startIndex: startIndex)
                let second: UInt8
                if Double.random(in: 0..<1, using: &rng) < F {
                    second = first
                } else {
                    second = sampleAllele(frequencies: frequencies, startIndex: startIndex)
                }
                return (min(first, second), max(first, second))
            }
        }

        /// Draws a single allele index from a cumulative allele-frequency distribution.
        private func sampleAllele(frequencies: [Double], startIndex: Int) -> UInt8 {
            let r = Double.random(in: 0..<1, using: &rng)
            var cumulative = 0.0
            for i in startIndex..<frequencies.count {
                cumulative += frequencies[i]
                if r < cumulative { return UInt8(i) }
            }
            return UInt8(frequencies.count - 1)
        }

        // MARK: - Initialization helpers

        /// Searches for an allele pair, drawn from the alleles actually
        /// observed among `offspring` at this locus (plus the null allele
        /// if `hasNullModel`), that's Mendelian-feasible for every one of
        /// them — i.e. every offspring shares at least one allele with the
        /// candidate mother, or (under a null model) is an apparent
        /// homozygote explainable by an invisible maternal null allele.
        ///
        /// This is a feasibility filter for seeding the chain, not a
        /// likelihood computation — with no maternal tissue sampled, any
        /// consistent starting genotype is refined by
        /// ``updateMaternalGenotypes()`` over subsequent steps. Falls back
        /// to allele `1` (or `0` if no non-null allele was ever observed)
        /// when no pair among the observed alleles is feasible for every
        /// offspring, which real data shouldn't produce.
        private static func feasibleMaternalGenotype(
            column: any GenotypeColumn, offspring: [Int], hasNullModel: Bool
        ) -> (UInt8, UInt8) {
            var candidates = Set<UInt8>()
            if hasNullModel { candidates.insert(0) }
            for ordinal in offspring {
                if let (l, r) = column.alleles(at: ordinal) {
                    if l != 0 { candidates.insert(l) }
                    if r != 0 { candidates.insert(r) }
                }
            }
            guard !candidates.isEmpty else { return (1, 1) }
            let sorted = candidates.sorted()

            for (i, a) in sorted.enumerated() {
                for b in sorted[i...] {
                    let feasible = offspring.allSatisfy { ordinal in
                        guard let (l, r) = column.alleles(at: ordinal) else { return true } // Missing offspring genotype imposes no constraint.
                        if l == a || l == b || r == a || r == b { return true }
                        // A homozygous offspring could be a masked null heterozygote.
                        return hasNullModel && l == r && (a == 0 || b == 0)
                    }
                    if feasible { return (a, b) }
                }
            }
            return (sorted[0], sorted[0])
        }

        /// The 7-category distribution over inbreeding histories implied by outcrossing rate `t`.
        ///
        /// `P(IH=0) = t`; `P(IH=k) = (1-t)^k * t` for `1 <= k < 6`; and
        /// `P(IH=6)` (six or more generations of selfing) absorbs the
        /// remainder, so the categories sum to `1`.
        private static func inbreedingHistoryCategoryProbabilities(t: Double) -> [Double] {
            var probabilities = [Double](repeating: 0.0, count: 7)
            probabilities[0] = t
            var cumulative = t
            for ih in 1..<6 {
                let p = pow(1.0 - t, Double(ih)) * t
                probabilities[ih] = p
                cumulative += p
            }
            probabilities[6] = 1.0 - cumulative
            return probabilities
        }

        /// Draws a category index from a discrete distribution via cumulative sampling.
        private static func sampleCategory(_ probabilities: [Double], using rng: inout SplitMix64) -> Int {
            let r = Double.random(in: 0..<1, using: &rng)
            var cumulative = 0.0
            for (category, p) in probabilities.enumerated() {
                cumulative += p
                if r < cumulative { return category }
            }
            return probabilities.count - 1
        }
    }
}
