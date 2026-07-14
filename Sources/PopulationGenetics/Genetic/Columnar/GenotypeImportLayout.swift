//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeImportLayout.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 6/28/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

/// Column-role configuration for importing a microsatellite table.
public struct GenotypeImportLayout: Sendable {

    /// Header of the family / maternal-tree (momID) column. Groups all rows of a family.
    public var familyColumn: String

    /// Header of the offspring-id column; a row whose value equals `motherMarker`
    /// is the family's mother (adult), others are offspring.
    public var offspringColumn: String

    /// Value in `offspringColumn` that marks the maternal (adult) row.
    public var motherMarker: String

    /// Optional individual-name column; if `nil`, names are synthesized as `family_offspringID`.
    public var nameColumn: String?

    /// Optional latitude / longitude columns (parsed as `Double`) for spatial work.
    public var latitudeColumn: String?
    /// Optional longitude column name (paired with `latitudeColumn`).
    public var longitudeColumn: String?

    /// Explicit locus columns, in order. If `nil`, every column that is not a
    /// metadata column (family/offspring/name/lat/lon) is treated as a locus.
    public var locusColumns: [String]?

    /// Allele separator within a genotype cell.
    public var alleleSeparator: Character

    /// Creates a layout configuration, all parameters optional with sensible defaults.
    ///
    /// - Parameters:
    ///   - familyColumn: Header of the family / momID column (default: `"momID"`).
    ///   - offspringColumn: Header of the offspring-id column (default: `"OffspringID"`).
    ///   - motherMarker: Value in `offspringColumn` that marks the maternal row (default: `"0"`).
    ///   - nameColumn: Optional individual-name column; synthesised from family+offspringID if `nil`.
    ///   - latitudeColumn: Optional latitude column name.
    ///   - longitudeColumn: Optional longitude column name.
    ///   - locusColumns: Explicit ordered locus column names; auto-detected if `nil`.
    ///   - alleleSeparator: Character separating alleles within a genotype cell (default: `":"`).
    public init(
        familyColumn: String = "momID",
        offspringColumn: String = "OffspringID",
        motherMarker: String = "0",
        nameColumn: String? = nil,
        latitudeColumn: String? = nil,
        longitudeColumn: String? = nil,
        locusColumns: [String]? = nil,
        alleleSeparator: Character = ":"
    ) {
        self.familyColumn = familyColumn
        self.offspringColumn = offspringColumn
        self.motherMarker = motherMarker
        self.nameColumn = nameColumn
        self.latitudeColumn = latitudeColumn
        self.longitudeColumn = longitudeColumn
        self.locusColumns = locusColumns
        self.alleleSeparator = alleleSeparator
    }
}
