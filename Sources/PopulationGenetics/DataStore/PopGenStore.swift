//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopGenStore.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//
//  Ergonomic query/mutation facade over the columnar storage model
//  (`GenotypeMatrix` + `GenotypeMatrixStore`), replacing the older UUID
//  dictionary-graph store. `GenotypeMatrix` is a fixed-shape batch structure
//  with no incremental `add*` API, and `GenotypeMatrixStore` is a fully
//  `async` actor built around whole-file SQLite round-trips — neither is
//  suited to the one-row-at-a-time mutation a SwiftUI app or an importer
//  needs. `PopGenStore` instead owns growable native "staging" arrays
//  (individuals, per-locus allele-index columns) that can be built up
//  incrementally, and materializes a `GenotypeMatrix` on demand for
//  algorithms and persistence.
//
//  Ordinals (array index) are the join key throughout, exactly matching the
//  columnar model's own convention — `individualOrdinal`/`locusOrdinal` are
//  reverse indices from UUID/name onto that same array position.
//
//  Note: allele lineage (`leftLineage`/`rightLineage`, used to color
//  maternal/paternal origin after simulated mating) is tracked here as
//  in-memory-only staging state. Unlike the old JSON-backed store, the
//  columnar SQLite schema has no lineage columns — lineage does not persist
//  across `save`/`load`.

import Foundation
import CoreLocation

/// Ergonomic, incrementally-mutable facade over columnar genotype storage.
public final class PopGenStore: ObservableObject {

    // MARK: - Individuals

    /// Individuals in ordinal order; index = individual ordinal.
    @Published public internal(set) var individuals: [Individual] = []

    /// Reverse index: individual UUID -> ordinal.
    var individualOrdinal: [UUID: Int] = [:]

    // MARK: - Loci

    /// Locus metadata in ordinal order; parallel to every other per-locus array below.
    var loci: [Locus] = []

    /// Reverse index: locus name -> ordinal. Locus names are assumed unique.
    var locusOrdinalByName: [String: Int] = [:]

    /// Reverse index: locus UUID -> ordinal.
    var locusOrdinalByID: [UUID: Int] = [:]

    /// Marker type per locus, parallel to `loci`.
    var markerTypes: [MarkerType] = []

    /// Allele codebook per locus, parallel to `loci`.
    var codebooks: [AlleleCodebook] = []

    /// Left/right allele index per (locus, individual): `leftAlleleIdx[locusOrdinal][individualOrdinal]`.
    var leftAlleleIdx: [[UInt8]] = []
    var rightAlleleIdx: [[UInt8]] = []

    /// Left/right lineage per (locus, individual). In-memory only; see file header.
    var leftLineage: [[Int8]] = []
    var rightLineage: [[Int8]] = []

    // MARK: - Strata

    /// Every stratum reference this store knows about, keyed by its canonical UUID.
    var allStrata: [UUID: StratumReference] = [:]

    /// Canonical stratum UUID per (level, name), so every individual tagged with
    /// the same (level, name) shares one `StratumReference.id`.
    var strataCatalog: [String: [String: UUID]] = [:]

    /// Each individual's stratum lineage, keyed by `Individual.id`.
    var individualStrata: [UUID: [StratumReference]] = [:]

    /// Reverse index: stratum UUID -> member individual UUIDs.
    var strataMembers: [UUID: Set<UUID>] = [:]

    /// Creates an empty store.
    public init() {}

    /// Creates a store pre-populated from an imported/loaded dataset.
    public init(dataset: ImportedDataset) {
        let matrix = dataset.matrix
        individuals = matrix.individuals
        individualOrdinal = Dictionary(uniqueKeysWithValues: individuals.enumerated().map { ($1.id, $0) })

        loci = matrix.loci
        locusOrdinalByName = Dictionary(uniqueKeysWithValues: loci.enumerated().map { ($1.name, $0) })
        locusOrdinalByID = Dictionary(uniqueKeysWithValues: loci.enumerated().map { ($1.id, $0) })
        markerTypes = matrix.columns.map(\.markerType)
        codebooks = matrix.columns.map(\.codebook)

        leftAlleleIdx = []
        rightAlleleIdx = []
        leftAlleleIdx.reserveCapacity(loci.count)
        rightAlleleIdx.reserveCapacity(loci.count)
        for column in matrix.columns {
            var left = [UInt8](repeating: 0, count: individuals.count)
            var right = [UInt8](repeating: 0, count: individuals.count)
            for i in 0..<individuals.count {
                let pair = column.alleles(at: i) ?? (0, 0)
                left[i] = pair.0
                right[i] = pair.1
            }
            leftAlleleIdx.append(left)
            rightAlleleIdx.append(right)
        }
        leftLineage = loci.map { _ in [Int8](repeating: Int8(Genotype.UnknownLineage), count: individuals.count) }
        rightLineage = loci.map { _ in [Int8](repeating: Int8(Genotype.UnknownLineage), count: individuals.count) }

        for (individualID, references) in dataset.strata {
            individualStrata[individualID] = references
            for reference in references {
                allStrata[reference.id] = reference
                strataMembers[reference.id, default: []].insert(individualID)
                strataCatalog[reference.level, default: [:]][reference.name] = reference.id
            }
        }
    }

    /// Materializes a `GenotypeMatrix` from the current staging state, packing
    /// each locus's allele-index arrays into the appropriate concrete column type.
    public var matrix: GenotypeMatrix {
        var columns: [any GenotypeColumn] = []
        columns.reserveCapacity(loci.count)
        for j in loci.indices {
            switch markerTypes[j] {
            case .microsatellite:
                columns.append(MultiallelicColumn(codebook: codebooks[j], left: leftAlleleIdx[j], right: rightAlleleIdx[j]))
            case .biallelicSNP:
                let codes = zip(leftAlleleIdx[j], rightAlleleIdx[j]).map(Self.dosageCode)
                columns.append(BiallelicColumn(codebook: codebooks[j], codes: codes))
            }
        }
        return GenotypeMatrix(individuals: individuals, loci: loci, columns: columns)
    }

    /// Maps a biallelic (left, right) allele-index pair to `BiallelicColumn`'s
    /// 2-bit dosage code (0 = missing, 1 = hom-ref, 2 = het, 3 = hom-alt).
    /// Partial calls (exactly one side missing) collapse to missing — the 2-bit
    /// scheme has no representation for a haploid/partial biallelic call.
    private static func dosageCode(left: UInt8, right: UInt8) -> UInt8 {
        switch (left, right) {
        case (0, 0): return 0
        case (1, 1): return 1
        case (1, 2), (2, 1): return 2
        case (2, 2): return 3
        default: return 0
        }
    }
}
