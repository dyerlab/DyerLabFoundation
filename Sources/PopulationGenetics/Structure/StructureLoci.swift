//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureLoci.swift
//  PopulationGenetics
//
//  The genotypes of a structure analysis, locus by locus, with no distance
//  matrix: every statistic comes from allele counts within strata. With δ² the
//  squared Euclidean distance halved, a stratum's sum of squares is
//  ½(Σ‖y‖² − ‖Σy‖²/n) over its units' allele vectors y, so
//
//  - gene copies (one-hot vectors, two per individual) give ½(m − Σc²/m),
//  - genotypes (allele-count vectors, Smouse & Peakall's distances) give
//    ½(2n + 2·homozygotes − Σc²/n),
//  - paternal gametes (2Gener's scored vectors) give the formula itself,
//
//  where c are the stratum's allele counts. Each locus uses the units
//  genotyped there, and the units are labelled once, so a permutation moves
//  an individual or gamete whole across every locus.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// The units, strata and per-locus genotypes of a structure analysis.
struct StructureLoci: Sendable {

    /// One locus's genotypes.
    enum Genotypes: Sendable {
        /// Diploid genotypes as allele indices, one pair per genotyped unit.
        case diploid(first: [UInt8], second: [UInt8])
        /// Scored allele vectors, one after another, one per unit.
        case scored([Double])
    }

    /// One locus.
    struct Locus: Sendable {
        /// The locus's name.
        let name: String
        /// One more than the largest allele index.
        let alleleSlots: Int
        /// The units genotyped here, as indices into the partition.
        let units: [Int]
        /// Their genotypes, in the same order.
        let genotypes: Genotypes
    }

    /// The loci, in matrix order.
    let loci: [Locus]
    /// Each unit's stratum, as an index into ``strata``.
    let partition: [Int]
    /// The strata's names, in order of first appearance.
    let strata: [String]
    /// How Hs and Ht are estimated from diploid genotypes.
    var heterozygosity: StructureSpec.Heterozygosity = .standard

    /// The number of units.
    var unitCount: Int { partition.count }

    // MARK: - Reading

    /// Reads adults' diploid genotypes.
    ///
    /// - Parameters:
    ///   - matrix: The genotypes.
    ///   - ordinals: The individuals, each a unit.
    ///   - strata: Each individual's stratum, in `ordinals` order.
    ///   - loci: The locus ordinals to read.
    ///   - heterozygosity: How Hs and Ht are estimated.
    /// - Returns: The loci, and the number of individuals lacking a diploid genotype at one or more of them.
    static func adults(matrix: GenotypeMatrix, ordinals: [Int], strata: [String],
                       loci: [Int], heterozygosity: StructureSpec.Heterozygosity = .standard)
        -> (loci: StructureLoci, incomplete: Int) {
        let (partition, names) = Self.partition(strata)
        var incomplete = Set<Int>()
        let read = loci.map { j -> Locus in
            let column = matrix.columns[j]
            var units: [Int] = [], first: [UInt8] = [], second: [UInt8] = []
            for (unit, ordinal) in ordinals.enumerated() {
                guard let (a, b) = column.alleles(at: ordinal), a != 0, b != 0 else {
                    incomplete.insert(unit)
                    continue
                }
                units.append(unit)
                first.append(a)
                second.append(b)
            }
            let slots = Int(max(first.max() ?? 0, second.max() ?? 0)) + 1
            return Locus(name: matrix.loci[j].name, alleleSlots: slots, units: units,
                         genotypes: .diploid(first: first, second: second))
        }
        return (StructureLoci(loci: read, partition: partition, strata: names, heterozygosity: heterozygosity),
                incomplete.count)
    }

    /// Numbers strata in order of first appearance.
    ///
    /// - Parameter labels: Each unit's stratum.
    /// - Returns: Each unit's stratum index, and the strata.
    static func partition(_ labels: [String]) -> (partition: [Int], strata: [String]) {
        var index: [String: Int] = [:], strata: [String] = []
        let partition = labels.map { label in
            if let i = index[label] { return i }
            strata.append(label)
            index[label] = strata.count - 1
            return strata.count - 1
        }
        return (partition, strata)
    }

    // MARK: - Evaluating

    /// Scratch space for one evaluation, sized for the largest locus.
    struct Workspace {
        var n: [Double]
        var homozygotes: [Double]
        var copies: [Double]
        var heterozygotes: [Double]
        var squares: [Double]

        init(strata: Int, slots: Int) {
            n = [Double](repeating: 0, count: strata)
            homozygotes = n
            squares = n
            copies = [Double](repeating: 0, count: strata * slots)
            heterozygotes = copies
        }
    }

    /// A workspace large enough for every locus.
    func makeWorkspace() -> Workspace {
        Workspace(strata: strata.count, slots: loci.map(\.alleleSlots).max() ?? 1)
    }

    /// Every locus's components under a labelling of the units.
    ///
    /// - Parameters:
    ///   - partition: Each unit's stratum.
    ///   - workspace: Scratch space from ``makeWorkspace()``.
    /// - Returns: Each locus's components, `nil` where it lacks two strata with more units than strata.
    func components(partition: [Int], workspace: inout Workspace) -> [LocusComponents?] {
        loci.map { components(of: $0, partition: partition, workspace: &workspace) }
    }

    /// One locus's components under a labelling of the units.
    ///
    /// - Parameters:
    ///   - locus: The locus.
    ///   - partition: Each unit's stratum.
    ///   - workspace: Scratch space.
    /// - Returns: The components, or `nil` without two strata and more units than strata.
    func components(of locus: Locus, partition: [Int], workspace w: inout Workspace) -> LocusComponents? {
        let r = strata.count, slots = locus.alleleSlots
        for i in 0..<r {
            w.n[i] = 0
            w.homozygotes[i] = 0
            w.squares[i] = 0
        }
        for k in 0..<(r * slots) {
            w.copies[k] = 0
            w.heterozygotes[k] = 0
        }
        switch locus.genotypes {
        case .diploid(let first, let second):
            for k in locus.units.indices {
                let i = partition[locus.units[k]], a = Int(first[k]), b = Int(second[k])
                w.n[i] += 1
                w.copies[i * slots + a] += 1
                w.copies[i * slots + b] += 1
                if a == b {
                    w.homozygotes[i] += 1
                } else {
                    w.heterozygotes[i * slots + a] += 1
                    w.heterozygotes[i * slots + b] += 1
                }
            }
            return diploid(slots: slots, workspace: w)
        case .scored(let scores):
            for k in locus.units.indices {
                let i = partition[locus.units[k]]
                w.n[i] += 1
                for u in 0..<slots {
                    let y = scores[k * slots + u]
                    w.copies[i * slots + u] += y
                    w.squares[i] += y * y
                }
            }
            return scored(slots: slots, workspace: w)
        }
    }

    /// The strata with units at the locus, and the totals over them.
    private func present(_ w: Workspace) -> [Int] {
        (0..<strata.count).filter { w.n[$0] > 0 }
    }

    /// Components from diploid allele counts.
    private func diploid(slots: Int, workspace w: Workspace) -> LocusComponents? {
        let present = present(w)
        let r = present.count
        let n = present.map { w.n[$0] }
        let total = n.reduce(0, +)
        guard r >= 2, total > Double(r) else { return nil }

        var totals = [Double](repeating: 0, count: slots)
        var squaresWithin = [Double](repeating: 0, count: r)   // Σ_u c_iu² per stratum
        var homozygotes = 0.0
        for (s, i) in present.enumerated() {
            homozygotes += w.homozygotes[i]
            for u in 0..<slots {
                let c = w.copies[i * slots + u]
                totals[u] += c
                squaresWithin[s] += c * c
            }
        }
        let squaresTotal = totals.reduce(0) { $0 + $1 * $1 }
        let alleles = totals.filter { $0 > 0 }.count

        // AMOVA of gene copies: m = 2n copies per stratum.
        let copyWithin = zip(n, squaresWithin).reduce(0) { $0 + (2 * $1.0 - $1.1 / (2 * $1.0)) / 2 }
        let geneCopies = VarianceParts.twoLevel(total: (2 * total - squaresTotal / (2 * total)) / 2,
                                                within: copyWithin, sizes: n.map { 2 * $0 })
        // AMOVA of genotypes: Σ‖c‖² is 4 per homozygote and 2 per heterozygote.
        let genotypeWithin = present.indices.reduce(0.0) { sum, s in
            sum + (2 * n[s] + 2 * w.homozygotes[present[s]] - squaresWithin[s] / n[s]) / 2
        }
        let genotypes = VarianceParts.twoLevel(total: (2 * total + 2 * homozygotes - squaresTotal / total) / 2,
                                               within: genotypeWithin, sizes: n)

        // Weir & Cockerham (Weir 1996, ch. 5), summed over alleles.
        let nc = (total - n.reduce(0) { $0 + $1 * $1 } / total) / Double(r - 1)
        var msAmong = 0.0, msIndividuals = 0.0, msWithin = 0.0
        for u in 0..<slots where totals[u] > 0 {
            let pBar = totals[u] / (2 * total)
            var among = 0.0, individuals = 0.0, within = 0.0
            for (s, i) in present.enumerated() {
                let p = w.copies[i * slots + u] / (2 * n[s])
                let h = w.heterozygotes[i * slots + u] / n[s]
                among += 2 * n[s] * (p - pBar) * (p - pBar)
                individuals += n[s] * (2 * p * (1 - p) - h / 2)
                within += n[s] * h
            }
            msAmong += among / Double(r - 1)
            msIndividuals += individuals / (total - Double(r))
            msWithin += within / (2 * total)
        }
        let a = (msAmong - msIndividuals) / (2 * nc), b = (msIndividuals - msWithin) / 2, c = msWithin
        let dfIndividuals = Int(total) - r
        let weirCockerham = VarianceParts(
            ss: [msAmong * Double(r - 1), msIndividuals * Double(dfIndividuals), msWithin * total],
            df: [r - 1, dfIndividuals, Int(total)], sigma: [a, b, c])

        // Hs and Ht by the chosen estimator (see StructureSpec+Heterozygosity).
        let harmonic = Double(r) / n.reduce(0) { $0 + 1 / $1 }
        let k = Double(r)
        var meanHomozygosity = 0.0, pBarSquares = 0.0, observed = 0.0
        for (s, i) in present.enumerated() {
            meanHomozygosity += squaresWithin[s] / (4 * n[s] * n[s])
            observed += (n[s] - w.homozygotes[i]) / n[s]
        }
        meanHomozygosity /= k
        observed /= k
        for u in 0..<slots where totals[u] > 0 {
            var pBar = 0.0
            for (s, i) in present.enumerated() { pBar += w.copies[i * slots + u] / (2 * n[s]) }
            pBar /= k
            pBarSquares += pBar * pBar
        }
        let hs: Double, ht: Double
        switch heterozygosity {
        case .neiChesser:
            hs = harmonic / (harmonic - 1) * (1 - meanHomozygosity - observed / (2 * harmonic))
            ht = 1 - pBarSquares + hs / (k * harmonic) - observed / (2 * k * harmonic)
        case .jost:
            hs = 2 * harmonic / (2 * harmonic - 1) * (1 - meanHomozygosity)
            ht = 1 - pBarSquares + hs / (2 * k * harmonic)
        case .uncorrected:
            hs = 1 - meanHomozygosity
            ht = 1 - pBarSquares
        }

        var numerators = [Double](repeating: 0, count: StructureSpec.Column.allCases.count)
        var denominators = numerators
        func set(_ column: StructureSpec.Column, _ numerator: Double, _ denominator: Double) {
            let i = LocusComponents.index[column] ?? 0
            numerators[i] = numerator
            denominators[i] = denominator
        }
        set(.theta, a, a + b + c)
        set(.fIS, b, b + c)
        set(.fIT, a + b, a + b + c)
        if let geneCopies { set(.phiGeneCopies, geneCopies.sigma[0], geneCopies.sigma[0] + geneCopies.sigma[1]) }
        if let genotypes { set(.phiGenotypes, genotypes.sigma[0], genotypes.sigma[0] + genotypes.sigma[1]) }
        set(.gst, ht - hs, ht)
        set(.gstPrime, (ht - hs) * (k - 1 + hs), ht * (k - 1) * (1 - hs))
        set(.dest, (ht - hs) * k / (k - 1), 1 - hs)

        return LocusComponents(locusCount: 1, units: Int(total), alleles: alleles, strata: r, hsSum: hs, htSum: ht,
                               geneCopies: geneCopies, genotypes: genotypes, gametes: nil,
                               weirCockerham: weirCockerham, numerators: numerators, denominators: denominators)
    }

    /// Components from scored gametes: the AMOVA alone.
    private func scored(slots: Int, workspace w: Workspace) -> LocusComponents? {
        let present = present(w)
        let n = present.map { w.n[$0] }
        let total = n.reduce(0, +)
        var totals = [Double](repeating: 0, count: slots)
        var within = 0.0, squares = 0.0
        for (s, i) in present.enumerated() {
            var vector = 0.0
            for u in 0..<slots {
                let v = w.copies[i * slots + u]
                totals[u] += v
                vector += v * v
            }
            within += (w.squares[i] - vector / n[s]) / 2
            squares += w.squares[i]
        }
        let totalSS = (squares - totals.reduce(0) { $0 + $1 * $1 } / total) / 2
        guard let gametes = VarianceParts.twoLevel(total: totalSS, within: within, sizes: n) else { return nil }

        var numerators = [Double](repeating: 0, count: StructureSpec.Column.allCases.count)
        var denominators = numerators
        let i = LocusComponents.index[.phiGametes] ?? 0
        numerators[i] = gametes.sigma[0]
        denominators[i] = gametes.sigma[0] + gametes.sigma[1]
        return LocusComponents(locusCount: 1, units: Int(total), alleles: totals.filter { $0 > 0 }.count,
                               strata: present.count, hsSum: .nan, htSum: .nan, geneCopies: nil, genotypes: nil,
                               gametes: gametes, weirCockerham: nil, numerators: numerators,
                               denominators: denominators)
    }
}
