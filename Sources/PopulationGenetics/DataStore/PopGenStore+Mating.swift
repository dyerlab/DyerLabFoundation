//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopGenStore+Mating.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//

import Foundation

// MARK: - Mating and Lineage

public extension PopGenStore {

    /// Sets an individual's lineage tracking at a locus based on comparison with
    /// a parent's genotype at that same locus.
    ///
    /// - Parameters:
    ///   - individual: The individual whose genotype lineage should be updated.
    ///   - locusName: The locus to update.
    ///   - parentGenotype: The parental genotype to compare against.
    ///   - isMom: `true` if the parent is maternal, `false` if paternal.
    func setLineage(individual: Individual, locusName: String, from parentGenotype: Genotype, isMom: Bool = true) {
        guard let j = locusOrdinalByName[locusName], let i = individualOrdinal[individual.id] else { return }
        let current = genotype(locusOrdinal: j, individualOrdinal: i)

        if current.isEmpty || parentGenotype.isEmpty { return }
        if current.ploidy != parentGenotype.ploidy || current.ploidy != Genotype.Diploid { return }

        var left = Genotype.UnknownLineage
        var right = Genotype.UnknownLineage

        if current.leftAllele == parentGenotype.leftAllele && current.rightAllele == parentGenotype.rightAllele {
            if current.isHeterozygote {
                left = Genotype.AmbiguousLineage
                right = Genotype.AmbiguousLineage
            } else {
                left = Genotype.MaternalLineage
                right = Genotype.PaternalLineage
            }
        } else if current.leftAllele == parentGenotype.leftAllele || current.leftAllele == parentGenotype.rightAllele {
            left = isMom ? Genotype.MaternalLineage : Genotype.PaternalLineage
            right = isMom ? Genotype.PaternalLineage : Genotype.MaternalLineage
        } else if current.rightAllele == parentGenotype.leftAllele || current.rightAllele == parentGenotype.rightAllele {
            right = isMom ? Genotype.MaternalLineage : Genotype.PaternalLineage
            left = isMom ? Genotype.PaternalLineage : Genotype.MaternalLineage
        } else {
            left = Genotype.ImpossibleLineage
            right = Genotype.ImpossibleLineage
        }

        leftLineage[j][i] = Int8(left)
        rightLineage[j][i] = Int8(right)
    }

    /// Assigns parental lineage tracking for every locus an individual and a
    /// parent share genotype calls at.
    func pullParent(for individual: Individual, from parent: Individual, isMom: Bool = true) {
        for locusName in getLocusNames(for: individual) {
            guard let parentGenotype = getGenotype(for: parent, locusName: locusName) else { continue }
            setLineage(individual: individual, locusName: locusName, from: parentGenotype, isMom: isMom)
        }
    }

    /// Produces and registers a new individual as the offspring of two parents,
    /// mating their genotype at every locus the mother has a call for.
    @discardableResult
    func mateIndividuals(mother: Individual, father: Individual) -> Individual {
        let offspring = addIndividual(name: "\(mother.name):\(father.name)",
                                       latitude: mother.latitude, longitude: mother.longitude)

        for locusName in getLocusNames(for: mother) {
            guard let momGeno = getGenotype(for: mother, locusName: locusName),
                  let dadGeno = getGenotype(for: father, locusName: locusName),
                  let result = mateGenotypes(mother: momGeno, father: dadGeno) else { continue }

            setGenotype(individual: offspring, locusName: locusName,
                        leftAllele: result.leftAllele, rightAllele: result.rightAllele,
                        leftLineage: result.leftLineage, rightLineage: result.rightLineage)
        }

        return offspring
    }

    /// Old-API-compatible entry point taking raw individual UUIDs.
    @discardableResult
    func mateIndividuals(motherID: UUID, fatherID: UUID) -> Individual? {
        guard let mother = getIndividual(id: motherID), let father = getIndividual(id: fatherID) else { return nil }
        return mateIndividuals(mother: mother, father: father)
    }
}
