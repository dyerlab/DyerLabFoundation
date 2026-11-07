//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ImportedDataset+Editing.swift
//  PopulationGenetics
//
//  Cell-level reads and edits, as a spreadsheet needs. `GenotypeMatrix` is
//  immutable, so each edit rebuilds the matrix with one value swapped in, which
//  is instant for thousands of individuals and tens of loci but not meant for
//  bulk changes.
//
//  Created by Rodney Dyer on 2026.10.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension ImportedDataset {

    // MARK: - Reading

    /// Whether genotypes at a locus can be edited.
    ///
    /// Only multiallelic (microsatellite-style) loci can for now; SNP loci are read-only.
    ///
    /// - Parameter locus: The locus's index in `matrix`.
    /// - Returns: `true` when the locus's genotypes can be changed.
    public func isEditableLocus(_ locus: Int) -> Bool {
        matrix.columns[locus] is MultiallelicColumn
    }

    // MARK: - Editing

    /// Moves an individual to a population, reusing the existing stratum when
    /// one already has that name, or creating a new one.
    ///
    /// - Parameters:
    ///   - name: The population's name.
    ///   - ordinal: The individual's row in `matrix`.
    public mutating func setPopulationName(_ name: String, at ordinal: Int) {
        let id = matrix.individuals[ordinal].id
        var lineage = strata[id] ?? []
        let level = lineage.last?.level ?? "Population"
        let existing = strata.values.lazy
            .compactMap(\.last)
            .first { $0.level == level && $0.name == name }
        let reference = existing ?? StratumReference(level: level, name: name)
        if lineage.isEmpty {
            lineage = [reference]
        } else {
            lineage[lineage.count - 1] = reference
        }
        strata[id] = lineage
    }

    /// Sets an individual's latitude.
    ///
    /// - Parameters:
    ///   - latitude: Decimal degrees (WGS84), or `nil` to clear it.
    ///   - ordinal: The individual's row in `matrix`.
    public mutating func setLatitude(_ latitude: Double?, at ordinal: Int) {
        var individuals = matrix.individuals
        individuals[ordinal].latitude = latitude
        matrix = GenotypeMatrix(individuals: individuals, loci: matrix.loci, columns: matrix.columns)
    }

    /// Sets an individual's longitude.
    ///
    /// - Parameters:
    ///   - longitude: Decimal degrees (WGS84), or `nil` to clear it.
    ///   - ordinal: The individual's row in `matrix`.
    public mutating func setLongitude(_ longitude: Double?, at ordinal: Int) {
        var individuals = matrix.individuals
        individuals[ordinal].longitude = longitude
        matrix = GenotypeMatrix(individuals: individuals, loci: matrix.loci, columns: matrix.columns)
    }

    /// Sets one genotype, adding any allele not yet seen at the locus.
    ///
    /// - Parameters:
    ///   - labels: The two allele labels, or `nil` for missing data.
    ///   - ordinal: The individual's row in `matrix`.
    ///   - locus: The locus's index in `matrix`.
    /// - Returns: `false`, leaving the dataset unchanged, if the locus is not
    ///   editable or already holds the maximum of 255 alleles.
    public mutating func setAlleles(_ labels: (String, String)?, at ordinal: Int, locus: Int) -> Bool {
        guard let column = matrix.columns[locus] as? MultiallelicColumn else { return false }
        var codebook = column.codebook
        var left = column.leftAlleleBytes
        var right = column.rightAlleleBytes
        if let (first, second) = labels {
            let newLabels = Set([first, second].filter { codebook.index(of: $0) == nil })
            guard codebook.count + newLabels.count <= 256 else { return false }
            left[ordinal] = codebook.register(first)
            right[ordinal] = codebook.register(second)
        } else {
            left[ordinal] = AlleleCodebook.nullIndex
            right[ordinal] = AlleleCodebook.nullIndex
        }
        var columns = matrix.columns
        columns[locus] = MultiallelicColumn(codebook: codebook, left: left, right: right)
        matrix = GenotypeMatrix(individuals: matrix.individuals, loci: matrix.loci, columns: columns)
        return true
    }
}
