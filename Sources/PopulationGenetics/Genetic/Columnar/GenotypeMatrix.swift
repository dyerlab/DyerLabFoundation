//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
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
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
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
    /// - Parameters:
    ///   - individuals: The individuals, in ordinal order.
    ///   - loci: The loci, in ordinal order.
    ///   - columns: One genotype column per locus.
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
    ///
    /// - Parameter name: The locus name.
    /// - Returns: The locus ordinal, or `nil`.
    public func locusIndex(named name: String) -> Int? {
        loci.firstIndex { $0.name == name }
    }

    /// Returns the column at a locus ordinal.
    ///
    /// - Parameter locusIndex: The locus ordinal.
    /// - Returns: The locus's genotype column.
    public func column(at locusIndex: Int) -> any GenotypeColumn {
        columns[locusIndex]
    }

    /// Returns the column for a named locus, or `nil` if not present.
    ///
    /// - Parameter name: The locus name.
    public func column(named name: String) -> (any GenotypeColumn)? {
        guard let i = locusIndex(named: name) else { return nil }
        return columns[i]
    }
}

// MARK: - Frequency reductions

extension GenotypeMatrix {

    /// Allele frequencies at a locus over a subset of individual ordinals.
    ///
    /// - Parameters:
    ///   - locusIndex: The locus ordinal.
    ///   - rows: The individual ordinals to include.
    /// - Returns: The accumulated frequencies.
    public func frequencies<Rows: Sequence>(atLocus locusIndex: Int, over rows: Rows) -> AlleleFrequencies
    where Rows.Element == Int {
        columns[locusIndex].frequencies(over: rows)
    }

    /// Allele frequencies at a locus over all individuals.
    ///
    /// - Parameter locusIndex: The locus ordinal.
    /// - Returns: The accumulated frequencies.
    public func frequencies(atLocus locusIndex: Int) -> AlleleFrequencies {
        columns[locusIndex].frequencies()
    }

    /// Allele frequencies for a named locus over a subset of individual ordinals,
    /// or `nil` if the locus is not present.
    ///
    /// - Parameters:
    ///   - name: The locus name.
    ///   - rows: The individual ordinals to include.
    /// - Returns: The accumulated frequencies, or `nil`.
    public func frequencies<Rows: Sequence>(forLocus name: String, over rows: Rows) -> AlleleFrequencies?
    where Rows.Element == Int {
        guard let i = locusIndex(named: name) else { return nil }
        return columns[i].frequencies(over: rows)
    }

    /// Allele frequencies for every locus (ordinal order) over a subset of
    /// individual ordinals — e.g. one stratum's multilocus frequencies.
    ///
    /// - Parameter rows: The individual ordinals to include.
    /// - Returns: One set of frequencies per locus.
    public func frequencies<Rows: Collection>(over rows: Rows) -> [AlleleFrequencies]
    where Rows.Element == Int {
        columns.map { $0.frequencies(over: rows) }
    }

    /// Allele frequencies for every locus over all individuals.
    ///
    /// - Returns: One set of frequencies per locus.
    public func frequencies() -> [AlleleFrequencies] {
        columns.map { $0.frequencies() }
    }
}
