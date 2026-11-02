//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TwoGenerGametes.swift
//  PopulationGenetics
//
//  Paternal gametes recovered from mother–offspring pairs and scored as
//  allele vectors, following Smouse et al. (2001), Tables 1–2 and eqs. 1–2:
//
//  - resolved paternal allele a: the indicator vector for a;
//  - ambiguous (mother and offspring share heterozygote i/k): qᵢ/(qᵢ+qₖ) on i
//    and qₖ/(qᵢ+qₖ) on k, with q the study-wide pollen-pool frequencies;
//  - missing (mother or offspring not scored at the locus): imputed as q
//    itself, each allele weighted by its pollen-pool frequency;
//  - impossible (offspring shares no allele with its mother at some locus):
//    the offspring is dropped from the analysis entirely.
//
//  The squared distance between gametes g and h is ½ Σₐ (Y_ga − Y_ha)²,
//  summed over loci, which reproduces every case in the paper's eqs. 5–6.
//  Every decision is recorded in `notes`, which the analysis report carries to the log.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

/// The scored paternal gametes of a 2Gener analysis.
struct TwoGenerGametes: Sendable {

    /// Family index (into the design's families) of each kept gamete.
    let partition: [Int]

    /// Offspring ordinal of each kept gamete.
    let offspring: [Int]

    /// Pollen-pool frequencies per locus, indexed by allele index (slot 0, the
    /// null allele, is always 0); empty for a locus that was left out.
    let pollenPool: [[Double]]

    /// `N × N` squared distances among kept gametes.
    let squaredDistances: [[Double]]

    /// The decisions made while recovering and scoring the gametes.
    let notes: [AnalysisNote]

    /// Offspring dropped as incompatible with their mother.
    let droppedCount: Int

    /// Offspring in families without a mother, not analysed.
    let motherlessOffspringCount: Int

    /// Loci with at least one recovered paternal allele (the loci used).
    let locusCount: Int

    /// Gamete-loci scored by their pollen-pool posterior.
    let ambiguousCount: Int

    /// Gamete-loci imputed from the pollen-pool frequencies.
    let imputedCount: Int

    /// Most EM iterations needed at any locus, or `nil` for ``PollenPoolFrequencyMethod/paternalAverage``.
    let iterations: Int?

    /// EM stops when no frequency changes by more than this.
    static let tolerance = 1e-12

    /// EM gives up after this many iterations (and logs a warning).
    static let maxIterations = 10_000

    /// Recovers, scores and compares the paternal gametes.
    ///
    /// - Parameters:
    ///   - matrix: Genotypes of mothers and offspring.
    ///   - design: The maternal families.
    ///   - method: How pollen-pool frequencies are estimated.
    init(matrix: GenotypeMatrix, design: ParentageDesign, method: PollenPoolFrequencyMethod) {
        var notes: [AnalysisNote] = []
        func note(_ type: LogType, _ message: String) {
            notes.append(AnalysisNote(type, message))
        }
        var droppedCount = 0
        var motherlessOffspringCount = 0
        let names = matrix.individuals.map(\.name)
        let L = matrix.locusCount

        // MARK: Recover gametes; drop impossible offspring.
        var partition: [Int] = []
        var offspring: [Int] = []
        var contributions: [[PaternalContribution]] = []   // [gamete][locus]
        for (f, family) in design.families.enumerated() {
            guard let mother = family.mother else {
                note(.warning, "Family \(family.id) has no mother, so its \(family.offspring.count) offspring "
                     + "were not analysed.")
                motherlessOffspringCount += family.offspring.count
                continue
            }
            for child in family.offspring {
                let recovered = (0..<L).map {
                    paternalGamete(offspringOrdinal: child, motherOrdinal: mother, in: matrix.columns[$0])
                }
                let impossible = (0..<L).filter { recovered[$0] == .impossible }
                guard impossible.isEmpty else {
                    let loci = impossible.map { matrix.loci[$0].name }.joined(separator: ", ")
                    note(.warning, "Offspring \(names[child]) was dropped: it shares no allele with its mother "
                         + "\(names[mother]) at \(loci).")
                    droppedCount += 1
                    continue
                }
                partition.append(f)
                offspring.append(child)
                contributions.append(recovered)
            }
        }

        // MARK: Pollen-pool frequencies per locus.
        var pollenPool: [[Double]] = []
        var maxIterations = 0
        var unconverged: [String] = []
        for j in 0..<L {
            let slots = matrix.columns[j].codebook.count
            var resolved = [Double](repeating: 0, count: slots)
            var ambiguous: [(Int, Int)] = []
            for gamete in contributions {
                switch gamete[j] {
                case .resolved(let a): resolved[Int(a)] += 1
                case .ambiguous(let a, let b): ambiguous.append((Int(a), Int(b)))
                case .missing, .impossible: break
                }
            }
            let n = resolved.reduce(0, +) + Double(ambiguous.count)
            guard n > 0 else {
                note(.warning, "Locus \(matrix.loci[j].name) has no recovered paternal alleles and was left out.")
                pollenPool.append([])
                continue
            }
            // Paternal average: ambiguous gametes split half and half.
            var counts = resolved
            for (a, b) in ambiguous { counts[a] += 0.5; counts[b] += 0.5 }
            var q = counts.map { $0 / n }

            if method == .expectationMaximization, !ambiguous.isEmpty {
                var converged = false
                var iteration = 0
                while iteration < Self.maxIterations, !converged {
                    iteration += 1
                    counts = resolved
                    for (a, b) in ambiguous {
                        let w = Self.weight(q[a], q[b])
                        counts[a] += w
                        counts[b] += 1 - w
                    }
                    let next = counts.map { $0 / n }
                    converged = zip(next, q).allSatisfy { abs($0 - $1) <= Self.tolerance }
                    q = next
                }
                maxIterations = max(maxIterations, iteration)
                if !converged { unconverged.append(matrix.loci[j].name) }
            }
            pollenPool.append(q)
        }

        switch method {
        case .paternalAverage:
            note(.assumption, "Pollen-pool allele frequencies were estimated across all \(contributions.count) "
                 + "paternal gametes by the paternal average (Smouse et al. 2001; GenAlEx): an ambiguous gamete "
                 + "counts half towards each candidate allele.")
        case .expectationMaximization:
            note(.assumption, "Pollen-pool allele frequencies were estimated across all \(contributions.count) "
                 + "paternal gametes by expectation–maximization, weighting each ambiguous gamete by its "
                 + "posterior qᵢ/(qᵢ+qₖ) (largest number of iterations at any locus: \(maxIterations)).")
            if !unconverged.isEmpty {
                note(.warning, "Expectation–maximization did not converge within \(Self.maxIterations) "
                     + "iterations at \(unconverged.joined(separator: ", ")); the last estimate was used.")
            }
        }

        // MARK: Score gametes as allele vectors and note ambiguity / imputation.
        var vectors = [[Double]](repeating: [], count: contributions.count)
        var ambiguousCount = 0
        var missingCount = 0
        for j in 0..<L where !pollenPool[j].isEmpty {
            let q = pollenPool[j]
            for (g, gamete) in contributions.enumerated() {
                var y = [Double](repeating: 0, count: q.count)
                switch gamete[j] {
                case .resolved(let a):
                    y[Int(a)] = 1
                case .ambiguous(let a, let b):
                    let w = Self.weight(q[Int(a)], q[Int(b)])
                    y[Int(a)] = w
                    y[Int(b)] = 1 - w
                    ambiguousCount += 1
                case .missing, .impossible:
                    y = q
                    missingCount += 1
                }
                vectors[g].append(contentsOf: y)
            }
        }
        if ambiguousCount > 0 {
            note(.assumption, "\(ambiguousCount) paternal gamete-loci were ambiguous (mother and offspring share "
                 + "a heterozygote) and were scored by their pollen-pool posterior qᵢ/(qᵢ+qₖ).")
        }
        if missingCount > 0 {
            note(.assumption, "\(missingCount) paternal gamete-loci had a missing mother or offspring genotype "
                 + "and were imputed with the pollen-pool allele frequencies.")
        }

        // MARK: Squared distances, ½ Σ (Y_g − Y_h)² over every allele of every kept locus.
        let count = vectors.count
        var distances = [[Double]](repeating: [Double](repeating: 0, count: count), count: count)
        for g in 0..<count {
            for h in (g + 1)..<count {
                var sum = 0.0
                for (a, b) in zip(vectors[g], vectors[h]) { sum += (a - b) * (a - b) }
                distances[g][h] = sum / 2
                distances[h][g] = sum / 2
            }
        }

        self.partition = partition
        self.offspring = offspring
        self.pollenPool = pollenPool
        self.squaredDistances = distances
        self.notes = notes
        self.droppedCount = droppedCount
        self.motherlessOffspringCount = motherlessOffspringCount
        self.locusCount = pollenPool.filter { !$0.isEmpty }.count
        self.ambiguousCount = ambiguousCount
        self.imputedCount = missingCount
        self.iterations = method == .expectationMaximization ? maxIterations : nil
    }

    /// The posterior that an ambiguous gamete carries allele `i` rather than `k`,
    /// `qᵢ / (qᵢ + qₖ)`, or one half if neither allele has been seen.
    static func weight(_ qi: Double, _ qk: Double) -> Double {
        qi + qk > 0 ? qi / (qi + qk) : 0.5
    }
}
