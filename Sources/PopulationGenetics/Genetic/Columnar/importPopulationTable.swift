//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  importPopulationTable.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Foundation

/// Column-role configuration for importing a population/strata genotype table
/// (adult individuals grouped into a hierarchy of strata, no parentage — as
/// opposed to `GenotypeImportLayout`'s family/offspring shape).
public struct PopulationImportLayout: Sendable {

    /// Header(s) of the hierarchical stratum columns, ordered outer to inner
    /// (e.g. `["Species", "Cluster", "Population"]`). Every individual is
    /// tagged with one `StratumReference` per configured level.
    public var strataColumns: [String]

    /// Optional individual-name column; if `nil`, names are synthesized as `row_<n>`.
    public var nameColumn: String?

    /// Optional latitude / longitude columns (parsed as `Double`) for spatial work.
    public var latitudeColumn: String?
    /// Optional longitude column name (paired with `latitudeColumn`).
    public var longitudeColumn: String?

    /// Explicit locus columns, in order. If `nil`, every column that is not a
    /// metadata column (strata/name/lat/lon) is treated as a locus.
    public var locusColumns: [String]?

    /// Allele separator within a genotype cell.
    public var alleleSeparator: Character

    /// Creates a layout configuration, all parameters optional with sensible defaults.
    public init(
        strataColumns: [String] = ["Population"],
        nameColumn: String? = nil,
        latitudeColumn: String? = nil,
        longitudeColumn: String? = nil,
        locusColumns: [String]? = nil,
        alleleSeparator: Character = ":"
    ) {
        self.strataColumns = strataColumns
        self.nameColumn = nameColumn
        self.latitudeColumn = latitudeColumn
        self.longitudeColumn = longitudeColumn
        self.locusColumns = locusColumns
        self.alleleSeparator = alleleSeparator
    }
}

/// Imports a population/strata genotype table into a `GenotypeMatrix` +
/// per-individual stratum lineage (no parentage — see `importMicrosatTable`
/// for family/offspring data).
///
/// - Parameters:
///   - csv: The raw CSV text (header row required).
///   - layout: Column-role configuration.
/// - Returns: The parsed matrix and each individual's stratum lineage.
public func importPopulationTable(csv: String, layout: PopulationImportLayout = .init()) throws -> ImportedDataset {

    let grid = csvToMatrix(raw: csv)
    guard let rawHeader = grid.first, !(rawHeader.count == 1 && rawHeader[0].isEmpty) else {
        throw GenotypeImportError.emptyInput
    }
    let header = rawHeader.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

    var columnIndex: [String: Int] = [:]
    for (i, name) in header.enumerated() { columnIndex[name] = i }

    func require(_ name: String) throws -> Int {
        guard let i = columnIndex[name] else { throw GenotypeImportError.missingColumn(name) }
        return i
    }

    let strataIdx = try layout.strataColumns.map { try require($0) }
    let nameIdx = try layout.nameColumn.map { try require($0) }
    let latIdx = try layout.latitudeColumn.map { try require($0) }
    let lonIdx = try layout.longitudeColumn.map { try require($0) }

    let metadata = Set(layout.strataColumns + [layout.nameColumn, layout.latitudeColumn, layout.longitudeColumn].compactMap { $0 })
    let locusNames: [String]
    if let explicit = layout.locusColumns {
        for name in explicit where columnIndex[name] == nil { throw GenotypeImportError.missingColumn(name) }
        locusNames = explicit
    } else {
        locusNames = header.filter { !metadata.contains($0) }
    }
    let locusIdx = try locusNames.map { try require($0) }

    var codebooks = [AlleleCodebook](repeating: AlleleCodebook(), count: locusNames.count)
    var lefts = [[UInt8]](repeating: [], count: locusNames.count)
    var rights = [[UInt8]](repeating: [], count: locusNames.count)

    var individuals: [Individual] = []
    var strata: [UUID: [StratumReference]] = [:]
    var strataCatalog: [String: [String: UUID]] = [:]

    func cell(_ row: [String], _ index: Int) -> String {
        index < row.count ? row[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }

    var ordinal = 0
    for rowNumber in 1..<grid.count {
        let row = grid[rowNumber]
        if row.count == 1 && row[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }

        let name = nameIdx.map { cell(row, $0) } ?? "row_\(ordinal)"
        let lat = latIdx.flatMap { Double(cell(row, $0)) }
        let lon = lonIdx.flatMap { Double(cell(row, $0)) }
        let individual = Individual(name: name, latitude: lat, longitude: lon)
        individuals.append(individual)

        var lineage: [StratumReference] = []
        for (level, colIndex) in zip(layout.strataColumns, strataIdx) {
            let stratumName = cell(row, colIndex)
            guard !stratumName.isEmpty else { continue }
            let stratumID = strataCatalog[level]?[stratumName] ?? UUID()
            strataCatalog[level, default: [:]][stratumName] = stratumID
            lineage.append(StratumReference(id: stratumID, level: level, name: stratumName))
        }
        if !lineage.isEmpty { strata[individual.id] = lineage }

        for (j, colIndex) in locusIdx.enumerated() {
            let raw = cell(row, colIndex)
            let parts = raw.split(separator: layout.alleleSeparator, omittingEmptySubsequences: false)
                           .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count <= 2 else {
                throw GenotypeImportError.malformedGenotype(locus: locusNames[j], row: rowNumber, value: raw)
            }
            let left = codebooks[j].register(parts.count > 0 ? parts[0] : "")
            let right = codebooks[j].register(parts.count > 1 ? parts[1] : "")
            lefts[j].append(left)
            rights[j].append(right)
        }

        ordinal += 1
    }

    var columns: [any GenotypeColumn] = []
    var loci: [Locus] = []
    columns.reserveCapacity(locusNames.count)
    for j in 0..<locusNames.count {
        columns.append(MultiallelicColumn(codebook: codebooks[j], left: lefts[j], right: rights[j]))
        loci.append(Locus(name: locusNames[j]))
    }

    let matrix = GenotypeMatrix(individuals: individuals, loci: loci, columns: columns)
    return ImportedDataset(matrix: matrix, parentage: ParentageDesign(families: []), strata: strata)
}
