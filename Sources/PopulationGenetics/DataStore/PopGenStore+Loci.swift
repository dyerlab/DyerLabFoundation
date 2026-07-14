//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopGenStore+Loci.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//

import Foundation

// MARK: - Locus Queries

public extension PopGenStore {

    /// Fetches all loci, sorted naturally by name.
    func getAllLoci() -> [Locus] {
        loci.naturalSorted(by: \.name)
    }

    /// Retrieves a specific locus by name.
    func getLocus(named: String) -> Locus? {
        guard let ordinal = locusOrdinalByName[named] else { return nil }
        return loci[ordinal]
    }

    /// Retrieves all loci with a specific name (typically returns 0 or 1 results).
    func getLoci(named: String) -> [Locus] {
        loci.filter { $0.name == named }
    }

    /// Creates and inserts a new locus, adding an all-missing column for every
    /// existing individual — O(individualCount).
    ///
    /// - Parameters:
    ///   - name: The name or identifier for this locus. Must be unique within the store.
    ///   - location: Physical location in base count (defaults to 0).
    ///   - contig: Contig or chromosome identifier (defaults to "").
    ///   - markerType: How this locus's genotypes are packed (defaults to `.microsatellite`).
    ///   - alleleProvenance: Where this locus's allele labels come from (defaults to `.observed`).
    /// - Returns: The newly created `Locus`.
    @discardableResult
    func addLocus(name: String, location: UInt = 0, contig: String = "",
                  markerType: MarkerType = .microsatellite,
                  alleleProvenance: Locus.AlleleProvenance = .observed) -> Locus {
        let newLocus = Locus(name: name, location: location, contig: contig, alleleProvenance: alleleProvenance)
        locusOrdinalByName[name] = loci.count
        locusOrdinalByID[newLocus.id] = loci.count
        loci.append(newLocus)
        markerTypes.append(markerType)
        codebooks.append(AlleleCodebook())
        leftAlleleIdx.append([UInt8](repeating: AlleleCodebook.nullIndex, count: individuals.count))
        rightAlleleIdx.append([UInt8](repeating: AlleleCodebook.nullIndex, count: individuals.count))
        leftLineage.append([Int8](repeating: Int8(Genotype.UnknownLineage), count: individuals.count))
        rightLineage.append([Int8](repeating: Int8(Genotype.UnknownLineage), count: individuals.count))
        return newLocus
    }

    /// Updates a locus's metadata (name/location/contig/provenance) in place.
    ///
    /// No-op if `locus.id` isn't already present. Does not change marker type or
    /// codebook — those are fixed at `addLocus` time.
    func updateLocus(_ locus: Locus) {
        guard let ordinal = locusOrdinalByID[locus.id] else { return }
        locusOrdinalByName.removeValue(forKey: loci[ordinal].name)
        loci[ordinal] = locus
        locusOrdinalByName[locus.name] = ordinal
    }
}
