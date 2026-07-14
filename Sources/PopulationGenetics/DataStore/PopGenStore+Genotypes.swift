//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopGenStore+Genotypes.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//

import Foundation

// MARK: - Genotype Queries

public extension PopGenStore {

    /// Retrieves all genotypes at a locus, one per individual (individual-ordinal
    /// order), including empty entries for individuals with no call at that locus.
    func getGenotypesFor(locusName: String) -> [Genotype] {
        guard let j = locusOrdinalByName[locusName] else { return [] }
        return (0..<individuals.count).map { genotype(locusOrdinal: j, individualOrdinal: $0) }
    }

    /// Retrieves all genotypes at a locus, one per individual.
    func getGenotypes(for locus: Locus) -> [Genotype] {
        getGenotypesFor(locusName: locus.name)
    }

    /// Retrieves all of an individual's genotypes, one per locus (locus-ordinal order).
    func getGenotypes(for individual: Individual) -> [Genotype] {
        guard let i = individualOrdinal[individual.id] else { return [] }
        return loci.indices.map { genotype(locusOrdinal: $0, individualOrdinal: i) }
    }

    /// Retrieves a specific individual's genotype at a named locus.
    func getGenotype(for individual: Individual, locusName: String) -> Genotype? {
        guard let j = locusOrdinalByName[locusName], let i = individualOrdinal[individual.id] else { return nil }
        return genotype(locusOrdinal: j, individualOrdinal: i)
    }

    /// Sets an individual's genotype at a named locus, registering new allele
    /// labels into that locus's codebook as needed.
    ///
    /// - Returns: The resulting `Genotype`, or `nil` if the individual or locus isn't in this store.
    @discardableResult
    func setGenotype(individual: Individual, locusName: String, leftAllele: String, rightAllele: String,
                      leftLineage newLeftLineage: Int = Genotype.UnknownLineage,
                      rightLineage newRightLineage: Int = Genotype.UnknownLineage) -> Genotype? {
        guard let j = locusOrdinalByName[locusName], let i = individualOrdinal[individual.id] else { return nil }

        let leftIndex = codebooks[j].register(leftAllele)
        let rightIndex = codebooks[j].register(rightAllele)
        leftAlleleIdx[j][i] = leftIndex
        rightAlleleIdx[j][i] = rightIndex
        leftLineage[j][i] = Int8(newLeftLineage)
        rightLineage[j][i] = Int8(newRightLineage)

        return genotype(locusOrdinal: j, individualOrdinal: i)
    }

    /// Returns a naturally-sorted list of locus names for which an individual has
    /// a non-missing genotype call.
    func getLocusNames(for individual: Individual) -> [String] {
        guard let i = individualOrdinal[individual.id] else { return [] }
        var names: [String] = []
        for j in loci.indices where leftAlleleIdx[j][i] != AlleleCodebook.nullIndex || rightAlleleIdx[j][i] != AlleleCodebook.nullIndex {
            names.append(loci[j].name)
        }
        return names.naturalSorted()
    }

    /// Builds the `Genotype` value at a given (locus, individual) ordinal pair
    /// from staging state. Internal — callers go through the name-based APIs above;
    /// `Genotype` itself carries no locus/individual back-reference, so it must
    /// always be interpreted in the context it was fetched from.
    internal func genotype(locusOrdinal j: Int, individualOrdinal i: Int) -> Genotype {
        Genotype(
            leftAllele: codebooks[j].label(for: leftAlleleIdx[j][i]),
            rightAllele: codebooks[j].label(for: rightAlleleIdx[j][i]),
            leftLingage: Int(leftLineage[j][i]),
            rightLineage: Int(rightLineage[j][i])
        )
    }
}
