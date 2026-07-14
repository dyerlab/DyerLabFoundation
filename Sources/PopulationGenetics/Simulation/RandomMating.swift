//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//
//  Created by Rodney Dyer on 4/23/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Foundation

// MARK: - Random Mating

/// Produces exactly `offspringCount` diploid offspring by random mating among the supplied parents.
///
/// Parents are sampled **with replacement**; each offspring draws an independent mother and
/// father (selfing is possible, matching the `gstudio` `mixed_mating(s = 0)` default).
/// Offspring are registered in `store` and returned.  The caller is responsible for naming
/// them (e.g. `"\(rep)-\(gen)-\(populationName)-\(i)"`) and for removing old-generation
/// individuals from the store to bound memory use.
///
/// - Parameters:
///   - parents: Individuals to draw from.  All must carry genotypes for the same set of loci.
///   - offspringCount: Exact number of offspring to produce.
///   - store: Data store that holds genotype relationships; updated in-place with offspring genotypes.
/// - Returns: Array of `Individual` offspring registered in `store`.
///
/// ## Example
///
/// ```swift
/// let parents = store.fetchIndividuals()
/// let offspring = randomMate(parents: parents, offspringCount: 100, store: store)
/// ```
public func randomMate(
    parents: [Individual],
    offspringCount: Int,
    store: PopGenStore
) -> [Individual] {

    guard !parents.isEmpty, offspringCount > 0 else { return [] }

    let locusNames = store.getLocusNames(for: parents[0])

    var offspring: [Individual] = []
    offspring.reserveCapacity(offspringCount)

    for i in 0..<offspringCount {
        let mother = parents[Int.random(in: 0..<parents.count)]
        let father = parents[Int.random(in: 0..<parents.count)]

        let child = store.addIndividual(name: "offspring-\(i)")

        for locusName in locusNames {
            guard let motherGeno = store.getGenotype(for: mother, locusName: locusName),
                  let fatherGeno = store.getGenotype(for: father, locusName: locusName),
                  let result = mateGenotypes(mother: motherGeno, father: fatherGeno) else { continue }

            store.setGenotype(individual: child, locusName: locusName,
                               leftAllele: result.leftAllele, rightAllele: result.rightAllele,
                               leftLineage: result.leftLineage, rightLineage: result.rightLineage)
        }

        offspring.append(child)
    }

    return offspring
}
