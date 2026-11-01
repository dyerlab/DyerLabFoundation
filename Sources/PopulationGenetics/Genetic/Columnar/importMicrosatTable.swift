//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  importMicrosatTable.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.06.28.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Imports a microsatellite table into a `GenotypeMatrix` + `ParentageDesign`.
///
/// - Parameters:
///   - csv: The raw CSV text (header row required).
///   - layout: Column-role configuration.
/// - Returns: The parsed matrix, parentage design (individual ordinals follow row order)
///   and each individual's stratum lineage.
/// - Throws: ``GenotypeImportError/emptyInput``, ``GenotypeImportError/missingColumn(_:)``,
///   ``GenotypeImportError/malformedGenotype(locus:row:value:)`` or
///   ``GenotypeImportError/duplicateMother(family:)``.
public func importMicrosatTable(csv: String, layout: GenotypeImportLayout = .init()) throws -> ImportedDataset {

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

    let familyIdx = try require(layout.familyColumn)
    let offspringIdx = try require(layout.offspringColumn)
    let strataIdx = try layout.strataColumns.map { try require($0) }
    let nameIdx = try layout.nameColumn.map { try require($0) }
    let latIdx = try layout.latitudeColumn.map { try require($0) }
    let lonIdx = try layout.longitudeColumn.map { try require($0) }

    let metadata = Set([layout.familyColumn, layout.offspringColumn,
                        layout.nameColumn, layout.latitudeColumn, layout.longitudeColumn].compactMap { $0 }
                       + layout.strataColumns)
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

    // Spreadsheets often write the marker back as "0.0" or "00".
    let markerValue = Double(layout.motherMarker)
    func isMother(_ value: String) -> Bool {
        if value == layout.motherMarker { return true }
        guard let markerValue, let number = Double(value) else { return false }
        return number == markerValue
    }

    var familyOrder: [String] = []
    var familyMother: [String: Int] = [:]
    var familyOffspring: [String: [Int]] = [:]

    func cell(_ row: [String], _ index: Int) -> String {
        index < row.count ? row[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }

    var ordinal = 0
    for rowNumber in 1..<grid.count {
        let row = grid[rowNumber]
        if row.count == 1 && row[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }

        let family = cell(row, familyIdx)
        let offspringValue = cell(row, offspringIdx)

        // A mother is named by her family ID alone; her offspring add their number.
        let name = nameIdx.map { cell(row, $0) }
            ?? (isMother(offspringValue) ? family : "\(family)_\(offspringValue)")
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

        if familyOffspring[family] == nil {
            familyOrder.append(family)
            familyOffspring[family] = []
        }
        if isMother(offspringValue) {
            if familyMother[family] != nil { throw GenotypeImportError.duplicateMother(family: family) }
            familyMother[family] = ordinal
        } else {
            familyOffspring[family]?.append(ordinal)
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

    let families = familyOrder.map { id in
        MaternalFamily(id: id, mother: familyMother[id], offspring: familyOffspring[id] ?? [])
    }
    let parentage = ParentageDesign(families: families)

    return ImportedDataset(matrix: matrix, parentage: parentage, strata: strata)
}
