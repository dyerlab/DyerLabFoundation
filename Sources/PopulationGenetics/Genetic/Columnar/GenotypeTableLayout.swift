//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeTableLayout.swift
//  PopulationGenetics
//
//  Column roles are read from the header alone, by name and position, so a
//  user's table needs no configuration in the common case. The population
//  column is the pivot: grouping columns sit to its left (outer to inner), and
//  the last recognised metadata column ends the metadata — everything after it
//  is a locus. Anything this can't place is reported in `unassignedColumns`
//  rather than guessed at, so an app can ask the user.
//
//  Created by Rodney Dyer on 2026.11.01.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The column roles of a genotype CSV, detected from its header row.
///
/// The expected shape is
///
/// ```
/// [Region, Species, …,] Population, [ID, [Offspring,]] [Latitude, Longitude,] Locus1, Locus2, …
/// ```
///
/// - Population (or Site, Locale, Pop, Stratum) is the innermost partition.
///   Unrecognised columns to its left are larger, alternative partitions,
///   ordered outer to inner, so individuals can be regrouped by any of them.
/// - ID identifies an individual. In parent/offspring data a mother and all
///   her offspring share an ID, and the Offspring column (or OffID,
///   OffspringID, Off) is `0` for the mother and non-zero for each offspring.
/// - Every column after the last recognised metadata column is a locus.
///
/// Header names are matched ignoring case, spaces and punctuation, so
/// `Off_ID`, `Offspring ID` and `offid` all name the offspring column.
public struct GenotypeTableLayout: Sendable, Equatable {

    /// The partition columns, outer to inner; the population column, if any, is last.
    public var partitionColumns: [String]

    /// The individual ID column (the family ID in parent/offspring data), if any.
    public var idColumn: String?

    /// The offspring column, if any. Its presence makes this a parent/offspring table.
    public var offspringColumn: String?

    /// The latitude column, if any.
    public var latitudeColumn: String?

    /// The longitude column, if any.
    public var longitudeColumn: String?

    /// The locus columns, in table order.
    public var locusColumns: [String]

    /// Metadata-position columns that couldn't be given a role: an unrecognised
    /// column right of the population column, or a second column for a role
    /// already taken (e.g. both `Lat` and `Latitude`). Empty for a clean header.
    public var unassignedColumns: [String]

    /// Whether the table holds mothers and their offspring rather than adults.
    public var isParentOffspring: Bool { offspringColumn != nil }

    // MARK: - Recognised names

    /// Normalised header names recognised as the population column.
    public static let populationNames: Set<String> = ["population", "pop", "site", "locale", "stratum"]

    /// Normalised header names recognised as the ID column.
    public static let idNames: Set<String> = ["id", "individual", "ind", "name", "sample", "sampleid"]

    /// Normalised header names recognised as the offspring column.
    public static let offspringNames: Set<String> = ["offspring", "offid", "offspringid", "off", "offspringno"]

    /// Normalised header names recognised as the latitude column.
    public static let latitudeNames: Set<String> = ["latitude", "lat"]

    /// Normalised header names recognised as the longitude column.
    public static let longitudeNames: Set<String> = ["longitude", "lon", "long", "lng"]

    // MARK: - Initialization

    /// Creates a layout from explicit column roles.
    ///
    /// - Parameters:
    ///   - partitionColumns: Partition columns, outer to inner, population last.
    ///   - idColumn: The ID column, if any.
    ///   - offspringColumn: The offspring column, if any.
    ///   - latitudeColumn: The latitude column, if any.
    ///   - longitudeColumn: The longitude column, if any.
    ///   - locusColumns: The locus columns, in order.
    ///   - unassignedColumns: Columns with no role (default none).
    public init(partitionColumns: [String],
                idColumn: String? = nil,
                offspringColumn: String? = nil,
                latitudeColumn: String? = nil,
                longitudeColumn: String? = nil,
                locusColumns: [String],
                unassignedColumns: [String] = []) {
        self.partitionColumns = partitionColumns
        self.idColumn = idColumn
        self.offspringColumn = offspringColumn
        self.latitudeColumn = latitudeColumn
        self.longitudeColumn = longitudeColumn
        self.locusColumns = locusColumns
        self.unassignedColumns = unassignedColumns
    }

    /// Detects the column roles of a header row.
    ///
    /// - Parameter header: The header row's column names, in table order.
    public init(header: [String]) {
        let header = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var roles: [Role?] = header.map { Self.role(of: $0) }

        // The first column claims a role; later claimants are left unassigned.
        var claimed: Set<Role> = []
        for (index, role) in roles.enumerated() {
            guard let role else { continue }
            if !claimed.insert(role).inserted { roles[index] = .duplicate }
        }

        let lastMetadata = roles.lastIndex { $0 != nil } ?? -1
        let population = roles.firstIndex(of: .population)
        // Grouping columns stop at the population column, or at the end of the
        // metadata when there is none.
        let partitionEnd = population ?? lastMetadata + 1

        var partitions: [String] = []
        var unassigned: [String] = []
        for index in 0..<(lastMetadata + 1) {
            switch roles[index] {
            case nil where index < partitionEnd: partitions.append(header[index])
            case nil, .duplicate: unassigned.append(header[index])
            default: break
            }
        }
        if let population { partitions.append(header[population]) }

        func column(_ role: Role) -> String? {
            roles.firstIndex(of: role).map { header[$0] }
        }

        self.init(partitionColumns: partitions,
                  idColumn: column(.id),
                  offspringColumn: column(.offspring),
                  latitudeColumn: column(.latitude),
                  longitudeColumn: column(.longitude),
                  locusColumns: Array(header[(lastMetadata + 1)...]),
                  unassignedColumns: unassigned)
    }

    /// Detects the column roles of a CSV's header row.
    ///
    /// - Parameter csv: The CSV text, header row first.
    /// - Throws: ``GenotypeImportError/emptyInput`` if there is no header row.
    public init(csv: String) throws {
        guard let header = csvToMatrix(raw: csv).first, !(header.count == 1 && header[0].isEmpty) else {
            throw GenotypeImportError.emptyInput
        }
        self.init(header: header)
    }

    // MARK: - Importer layouts

    /// The layout for `importPopulationTable`, for an adult table.
    public var populationLayout: PopulationImportLayout {
        PopulationImportLayout(strataColumns: partitionColumns,
                               nameColumn: idColumn,
                               latitudeColumn: latitudeColumn,
                               longitudeColumn: longitudeColumn,
                               locusColumns: locusColumns)
    }

    /// The layout for `importMicrosatTable`, for a parent/offspring table.
    ///
    /// - Throws: ``GenotypeImportError/missingColumn(_:)`` if the table has no
    ///   offspring column, or no ID column to group its families by.
    public func parentageLayout() throws -> GenotypeImportLayout {
        guard let offspringColumn else { throw GenotypeImportError.missingColumn("Offspring") }
        guard let idColumn else { throw GenotypeImportError.missingColumn("ID") }
        return GenotypeImportLayout(familyColumn: idColumn,
                                    offspringColumn: offspringColumn,
                                    strataColumns: partitionColumns,
                                    latitudeColumn: latitudeColumn,
                                    longitudeColumn: longitudeColumn,
                                    locusColumns: locusColumns)
    }

    /// Imports `csv` with this layout: as parent/offspring data when there is an
    /// offspring column, otherwise as adults.
    ///
    /// - Parameter csv: The CSV text this layout was detected from.
    /// - Returns: The imported dataset, with parentage for parent/offspring data.
    /// - Throws: The errors of ``parentageLayout()``, `importMicrosatTable` or `importPopulationTable`.
    public func importTable(csv: String) throws -> ImportedDataset {
        isParentOffspring
            ? try importMicrosatTable(csv: csv, layout: parentageLayout())
            : try importPopulationTable(csv: csv, layout: populationLayout)
    }

    // MARK: - Helpers

    /// A metadata role a header can name.
    private enum Role {
        case population, id, offspring, latitude, longitude
        /// A second column naming a role already taken.
        case duplicate
    }

    /// The role a header names, or `nil` if it names none.
    private static func role(of name: String) -> Role? {
        let key = normalized(name)
        if populationNames.contains(key) { return .population }
        if idNames.contains(key) { return .id }
        if offspringNames.contains(key) { return .offspring }
        if latitudeNames.contains(key) { return .latitude }
        if longitudeNames.contains(key) { return .longitude }
        return nil
    }

    /// Lowercases a header and drops everything but letters and digits.
    private static func normalized(_ name: String) -> String {
        String(name.lowercased().unicodeScalars.filter(CharacterSet.alphanumerics.contains))
    }
}
