//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  HardyWeinbergAnalysis.swift
//  PopulationGenetics
//
//  gstudio's hwe.test() (1.15.4) for one locus in one set of individuals: a
//  chi-square goodness-of-fit test of the genotype counts against Hardy–
//  Weinberg proportions, with ℓ(ℓ − 1)/2 degrees of freedom for ℓ alleles and
//  Yates' continuity correction, |O − E| − ½, whenever any expected count is
//  under 5. Every genotype the alleles can form enters the sum, observed or
//  not. Unlike gstudio, a locus with a single allele has no test (`nil`):
//  with no degrees of freedom there is nothing to test.
//  Fixture: `Fixtures/generate_hwe_fixtures.R`.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// A chi-square test for Hardy–Weinberg equilibrium at one locus (`AnalysisType.hardyWeinberg`).
///
/// ## Usage
///
/// ```swift
/// if let test = HardyWeinbergAnalysis(matrix: genotypes, locus: 0),
///    let run = test.perform() {
///     print(run.outcome.statistic, run.outcome.pValue ?? .nan)
/// }
/// ```
public struct HardyWeinbergAnalysis: Analysis {

    /// `AnalysisType.hardyWeinberg`.
    public static let analysisType: AnalysisType = .hardyWeinberg

    /// Fewer individuals than this draws a warning that the chi-square approximation may be poor.
    public static let smallSample = 50

    /// The locus's name.
    public let locus: String

    /// The stratum tested, or `nil` for the individuals as a whole.
    public let stratum: String?

    /// Every genotype the observed alleles can form, in label order, with its counts.
    public let counts: [GenotypeCount]

    /// The alleles seen.
    public let alleleCount: Int

    /// The individuals genotyped at the locus.
    public var sampleSize: Int { counts.reduce(0) { $0 + $1.observed } }

    /// Whether the continuity correction is applied: some expected count is under 5.
    public var isCorrected: Bool { counts.contains { $0.expected < 5 } }

    /// Warnings on the approximation, as gstudio gives them.
    public var notes: [AnalysisNote] {
        let at = stratum.map { "\(locus) in \($0)" } ?? locus
        var notes: [AnalysisNote] = []
        if sampleSize < Self.smallSample {
            notes.append(AnalysisNote(.warning, "Under \(Self.smallSample) individuals at \(at) (\(sampleSize)), so "
                                      + "the chi-square approximation may be poor."))
        }
        if isCorrected {
            notes.append(AnalysisNote(.warning, "Fewer than 5 genotypes are expected at \(at), so the continuity "
                                      + "correction was applied; consider collapsing rare alleles."))
        }
        return notes
    }

    /// Counts the genotypes at a locus.
    ///
    /// - Parameters:
    ///   - matrix: The genotypes.
    ///   - locus: The locus ordinal.
    ///   - ordinals: The individuals' rows, or `nil` (the default) for every individual. Individuals not genotyped
    ///     at the locus are left out.
    ///   - stratum: The stratum's name, for the report, or `nil`.
    /// - Returns: `nil` if no individual is genotyped at the locus or it has a single allele.
    public init?(matrix: GenotypeMatrix, locus: Int, over ordinals: [Int]? = nil, stratum: String? = nil) {
        guard matrix.loci.indices.contains(locus) else { return nil }
        let column = matrix.columns[locus]
        let codebook = column.codebook
        var observed: [String: Int] = [:]
        var alleleCounts = [Int](repeating: 0, count: codebook.count)
        var n = 0
        for row in ordinals ?? Array(matrix.individuals.indices) {
            guard let (a, b) = column.alleles(at: row), a != 0, b != 0 else { continue }
            let (x, y) = codebook.label(for: a) <= codebook.label(for: b) ? (a, b) : (b, a)
            observed["\(codebook.label(for: x)):\(codebook.label(for: y))", default: 0] += 1
            alleleCounts[Int(a)] += 1
            alleleCounts[Int(b)] += 1
            n += 1
        }
        let alleles = alleleCounts.indices.filter { $0 > 0 && alleleCounts[$0] > 0 }.map { UInt8($0) }
            .sorted { codebook.label(for: $0) < codebook.label(for: $1) }
        guard n > 0, alleles.count > 1 else { return nil }

        var counts: [GenotypeCount] = []
        for (i, a) in alleles.enumerated() {
            let p = Double(alleleCounts[Int(a)]) / Double(2 * n)
            for b in alleles[i...] {
                let q = Double(alleleCounts[Int(b)]) / Double(2 * n)
                let genotype = "\(codebook.label(for: a)):\(codebook.label(for: b))"
                counts.append(GenotypeCount(genotype: genotype, observed: observed[genotype] ?? 0,
                                            expected: Double(n) * (a == b ? p * q : 2 * p * q)))
            }
        }
        self.locus = matrix.loci[locus].name
        self.stratum = stratum
        self.counts = counts
        self.alleleCount = alleles.count
    }

    /// Computes the chi-square statistic and its P.
    ///
    /// - Parameter options: Unused; the test is analytic.
    /// - Returns: The outcome; never `nil`.
    public func run(options: AnalysisOptions = AnalysisOptions()) -> HardyWeinbergOutcome? {
        let correction = isCorrected ? 0.5 : 0
        let chi = counts.reduce(0.0) { sum, count in
            let deviation = abs(Double(count.observed) - count.expected) - correction
            return sum + deviation * deviation / count.expected
        }
        let df = alleleCount * (alleleCount - 1) / 2
        return HardyWeinbergOutcome(locus: locus, stratum: stratum, statistic: chi, degreesOfFreedom: df,
                                    pValue: chiSquareUpperTail(chi, degreesOfFreedom: Double(df)),
                                    isCorrected: isCorrected, sampleSize: sampleSize, counts: counts)
    }
}
