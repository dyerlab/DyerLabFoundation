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
//  Created by Rodney Dyer on 2026.06.28.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// Column-role configuration for importing a microsatellite table.
public struct GenotypeImportLayout: Sendable {

    /// Header of the family / maternal-tree (momID) column. Groups all rows of a family.
    public var familyColumn: String

    /// Header of the offspring-id column; a row whose value equals `motherMarker`
    /// is the family's mother (adult), others are offspring.
    public var offspringColumn: String

    /// Value in `offspringColumn` that marks the maternal (adult) row. Numeric
    /// values match numerically, so `0.0` and `00` also mark a mother when this is `"0"`.
    public var motherMarker: String

    /// Header(s) of the hierarchical stratum columns, ordered outer to inner
    /// (e.g. `["Region", "Population"]`). Every individual — mother or
    /// offspring — is tagged with one `StratumReference` per configured level.
    public var strataColumns: [String]

    /// Optional individual-name column; if `nil`, a mother is named by her
    /// family ID and each offspring as `family_offspringID`.
    public var nameColumn: String?

    /// Optional latitude / longitude columns (parsed as `Double`) for spatial work.
    public var latitudeColumn: String?
    /// Optional longitude column name (paired with `latitudeColumn`).
    public var longitudeColumn: String?

    /// Explicit locus columns, in order. If `nil`, every column that is not a
    /// metadata column (family/offspring/strata/name/lat/lon) is treated as a locus.
    public var locusColumns: [String]?

    /// Allele separator within a genotype cell.
    public var alleleSeparator: Character

    /// Creates a layout configuration, all parameters optional with sensible defaults.
    ///
    /// - Parameters:
    ///   - familyColumn: Header of the family / momID column (default: `"momID"`).
    ///   - offspringColumn: Header of the offspring-id column (default: `"OffspringID"`).
    ///   - motherMarker: Value in `offspringColumn` that marks the maternal row (default: `"0"`).
    ///   - strataColumns: Stratum column headers, outer to inner (default none).
    ///   - nameColumn: Optional individual-name column; if `nil`, mothers are named by family and
    ///     offspring as `family_offspringID`.
    ///   - latitudeColumn: Optional latitude column name.
    ///   - longitudeColumn: Optional longitude column name.
    ///   - locusColumns: Explicit ordered locus column names; auto-detected if `nil`.
    ///   - alleleSeparator: Character separating alleles within a genotype cell (default: `":"`).
    public init(
        familyColumn: String = "momID",
        offspringColumn: String = "OffspringID",
        motherMarker: String = "0",
        strataColumns: [String] = [],
        nameColumn: String? = nil,
        latitudeColumn: String? = nil,
        longitudeColumn: String? = nil,
        locusColumns: [String]? = nil,
        alleleSeparator: Character = ":"
    ) {
        self.familyColumn = familyColumn
        self.offspringColumn = offspringColumn
        self.motherMarker = motherMarker
        self.strataColumns = strataColumns
        self.nameColumn = nameColumn
        self.latitudeColumn = latitudeColumn
        self.longitudeColumn = longitudeColumn
        self.locusColumns = locusColumns
        self.alleleSeparator = alleleSeparator
    }
}
