//
//  GenotypeMatrix.swift
//  PopulationGenetics
//
//  Columnar core: the in-memory genotype container. Individuals are addressed by
//  ordinal (their position in `individuals`); each locus has a parallel packed
//  column. A statistic is a column reduced over a set of individual ordinals, so
//  groupings (strata) and permutation/null models are just different index sets
//  passed to the same reduction.
//

import Foundation

/// A locus-major genotype matrix: ordered individuals × ordered loci, with one
/// packed ``GenotypeColumn`` per locus.
///
/// Individuals are identified by ordinal (`0..<individualCount`). Each locus in
/// `loci` has a column at the same index in `columns`, and every column holds
/// exactly `individualCount` genotypes.
public struct GenotypeMatrix: Sendable {

    /// Individuals in ordinal order; index = individual ordinal.
    public let individuals: [Individual]

    /// Locus metadata in ordinal order; parallel to `columns`.
    public let loci: [Locus]

    /// Packed genotype columns, parallel to `loci`.
    public let columns: [any GenotypeColumn]

    /// Creates a matrix from parallel individuals, loci, and columns.
    ///
    /// - Precondition: `loci.count == columns.count`, and every column's `count`
    ///   equals `individuals.count`.
    public init(individuals: [Individual], loci: [Locus], columns: [any GenotypeColumn]) {
        precondition(loci.count == columns.count, "loci and columns must be parallel")
        let n = individuals.count
        precondition(columns.allSatisfy { $0.count == n },
                     "every column must have one genotype per individual")
        self.individuals = individuals
        self.loci = loci
        self.columns = columns
    }

    /// Number of individuals (valid ordinals are `0..<individualCount`).
    public var individualCount: Int { individuals.count }

    /// Number of loci.
    public var locusCount: Int { loci.count }
}


// MARK: - Locus / column access

extension GenotypeMatrix {

    /// Returns the ordinal of the first locus with the given name, or `nil`.
    public func locusIndex(named name: String) -> Int? {
        loci.firstIndex { $0.name == name }
    }

    /// Returns the column at a locus ordinal.
    public func column(at locusIndex: Int) -> any GenotypeColumn {
        columns[locusIndex]
    }

    /// Returns the column for a named locus, or `nil` if not present.
    public func column(named name: String) -> (any GenotypeColumn)? {
        guard let i = locusIndex(named: name) else { return nil }
        return columns[i]
    }
}


// MARK: - Frequency reductions

extension GenotypeMatrix {

    /// Allele frequencies at a locus over a subset of individual ordinals.
    public func frequencies<Rows: Sequence>(atLocus locusIndex: Int, over rows: Rows) -> AlleleFrequencies
    where Rows.Element == Int {
        columns[locusIndex].frequencies(over: rows)
    }

    /// Allele frequencies at a locus over all individuals.
    public func frequencies(atLocus locusIndex: Int) -> AlleleFrequencies {
        columns[locusIndex].frequencies()
    }

    /// Allele frequencies for a named locus over a subset of individual ordinals,
    /// or `nil` if the locus is not present.
    public func frequencies<Rows: Sequence>(forLocus name: String, over rows: Rows) -> AlleleFrequencies?
    where Rows.Element == Int {
        guard let i = locusIndex(named: name) else { return nil }
        return columns[i].frequencies(over: rows)
    }

    /// Allele frequencies for every locus (ordinal order) over a subset of
    /// individual ordinals — e.g. one stratum's multilocus frequencies.
    public func frequencies<Rows: Collection>(over rows: Rows) -> [AlleleFrequencies]
    where Rows.Element == Int {
        columns.map { $0.frequencies(over: rows) }
    }

    /// Allele frequencies for every locus over all individuals.
    public func frequencies() -> [AlleleFrequencies] {
        columns.map { $0.frequencies() }
    }
}
