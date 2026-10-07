//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  LocusSubsampleNull.swift
//  PopulationGenetics
//
//  A port of gstudio's `locus_subsample_null()` (>= 1.15): rebuild the
//  Population Graph from random subsets of polymorphic loci and record the
//  genetic-gravity mean |Δ| alongside the polymorphism of the loci used — an
//  information-loss reference for the asymmetry index. See
//  `~/Coding/gstudio/R/locus_subsample_null.R`.
//

import Matrix
import Graph
import Foundation

/// One locus subset from ``LocusSubsampleNull(genotypes:groups:lociPerSubset:subsets:gamma:seed:)``
/// — mirrors a row of gstudio's `locus_subsample_null()` table.
public struct LocusSubsampleDraw: Sendable, Equatable {
    /// Number of loci in the subset (`k`).
    public let k: Int
    /// Replicate number within this `k` (1-based, `subset`).
    public let subset: Int
    /// The loci drawn, in draw order.
    public let loci: [String]
    /// Loci in the subset polymorphic in the stratum-averaged frequencies
    /// (`n_poly_global`).
    public let polymorphicGlobal: Int
    /// Mean number of subset loci polymorphic within a stratum (`n_poly_pop`).
    public let polymorphicPerPopulation: Double
    /// Mean within-stratum expected heterozygosity `1 − Σp²` over strata × loci (`He`).
    public let expectedHeterozygosity: Double
    /// Edges in the rebuilt Population Graph (`n_edges`); `nil` if it could not be built.
    public let edgeCount: Int?
    /// Mean `|Δ|` over its edges at `gamma` (`mean_abs_delta`); `nil` if the
    /// graph could not be built, `.nan` if it has no edges.
    public let meanAbsDelta: Double?
    /// Whether the graph was built (`ok`).
    public var succeeded: Bool { edgeCount != nil }
}

/// Information-loss reference for the asymmetry index — a port of gstudio's
/// `locus_subsample_null()`.
///
/// Loci polymorphic in the stratum-averaged allele frequencies are identified;
/// then, for each subset size `k` (those not exceeding the number of
/// polymorphic loci) and each of `subsets` replicates, `k` of them are drawn
/// at random, the Population Graph is rebuilt from those loci alone
/// (``PopulationGraph(x:groups:alpha:tol:)``), and its mean genetic-gravity
/// `|Δ|` (``GravityEdges(graph:gamma:x:)``) is recorded with the subset's
/// polymorphism and heterozygosity. With the same `seed` the locus draws match
/// R's `set.seed(seed); locus_subsample_null(x, ...)`.
///
/// - Parameters:
///   - genotypes: The genotype data.
///   - groups: The stratum label for each individual.
///   - lociPerSubset: Subset sizes `k` (default `[2, 3, 4, 5, 6, 8, 10, 12]`).
///   - subsets: Replicate subsets per size (default `3`).
///   - gamma: Bandwidth multiplier for `Δ` (default `0.5`).
///   - seed: RNG seed, equivalent to R's `set.seed(seed)`.
/// - Returns: One draw per (size, replicate), or `nil` if `groups` does not
///   have one label per individual or there are no loci.
public func LocusSubsampleNull(genotypes: GenotypeMatrix,
                               groups: [String],
                               lociPerSubset: [Int] = [2, 3, 4, 5, 6, 8, 10, 12],
                               subsets: Int = 3,
                               gamma: Double = 0.5,
                               seed: Int) -> [LocusSubsampleDraw]? {
    guard groups.count == genotypes.individualCount, genotypes.locusCount > 0 else { return nil }

    let strata = Array(Set(groups)).sorted()
    var rowsByStratum: [String: [Int]] = [:]
    for (row, group) in groups.enumerated() { rowsByStratum[group, default: []].append(row) }

    // Per stratum × locus allele frequencies over the codebook's alleles
    // (zero-filled, as gstudio's frequencies(x, stratum)).
    let frequencies: [[[Double]]] = strata.map { stratum in
        let rows = rowsByStratum[stratum] ?? []
        return (0..<genotypes.locusCount).map { locus in
            let counts = genotypes.frequencies(atLocus: locus, over: rows)
            return genotypes.column(at: locus).codebook.alleleIndices.map { counts.frequency(forIndex: $0) }
        }
    }
    func isPolymorphic(_ p: [Double]) -> Bool { p.contains { $0 > 0 && $0 < 1 } }
    func stratumMean(locus: Int) -> [Double] {
        let alleles = frequencies.first?[locus].count ?? 0
        return (0..<alleles).map { a in frequencies.reduce(0.0) { $0 + $1[locus][a] } / Double(strata.count) }
    }

    // Polymorphic loci, in locus order.
    let polymorphic = (0..<genotypes.locusCount).filter { isPolymorphic(stratumMean(locus: $0)) }

    var rng = RMersenneTwister(seed: seed)
    var draws: [LocusSubsampleDraw] = []
    for k in lociPerSubset where k <= polymorphic.count {
        for replicate in 1...max(subsets, 1) where subsets > 0 {
            let chosen = rng.sample(polymorphic, size: k)                 // R: sample(poly, kk)

            let polymorphicGlobal = chosen.filter { isPolymorphic(stratumMean(locus: $0)) }.count
            let polymorphicPerPopulation = frequencies.map { stratum in
                Double(chosen.filter { isPolymorphic(stratum[$0]) }.count)
            }.reduce(0, +) / Double(strata.count)
            let heterozygosity = frequencies.flatMap { stratum in
                chosen.map { 1.0 - stratum[$0].reduce(0.0) { $0 + $1 * $1 } }
            }.filter { !$0.isNaN }
            let he = heterozygosity.isEmpty ? .nan : heterozygosity.reduce(0, +) / Double(heterozygosity.count)

            // R: popgraph(to_mv(x[, L]), groups) on the drawn loci, in draw order.
            let subset = GenotypeMatrix(individuals: genotypes.individuals,
                                        loci: chosen.map { genotypes.loci[$0] },
                                        columns: chosen.map { genotypes.columns[$0] })
            var edgeCount: Int?
            var meanAbsDelta: Double?
            if let graph = PopulationGraph(x: subset.multivariateMatrix(), groups: groups),
               let edges = GravityEdges(graph: graph, gamma: gamma) {
                edgeCount = edges.count
                meanAbsDelta = edges.isEmpty ? .nan : edges.reduce(0.0) { $0 + abs($1.delta) } / Double(edges.count)
            }

            draws.append(LocusSubsampleDraw(k: k, subset: replicate,
                                            loci: chosen.map { genotypes.loci[$0].name },
                                            polymorphicGlobal: polymorphicGlobal,
                                            polymorphicPerPopulation: polymorphicPerPopulation,
                                            expectedHeterozygosity: he,
                                            edgeCount: edgeCount, meanAbsDelta: meanAbsDelta))
        }
    }
    return draws
}
