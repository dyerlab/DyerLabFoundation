//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMatrix+ParentageDesign.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 6/28/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

// MARK: - Pollen-pool reductions over a GenotypeMatrix

extension GenotypeMatrix {

    /// Allele frequencies among the adults (mothers) of a parentage design at a locus.
    public func adultFrequencies(atLocus locusIndex: Int, design: ParentageDesign) -> AlleleFrequencies {
        frequencies(atLocus: locusIndex, over: design.adultOrdinals)
    }

    /// The pollen pool a single mother sampled, at one locus.
    ///
    /// For each offspring the maternal contribution is removed (see
    /// ``paternalGamete(offspring:mother:)``) and the recovered paternal gametes
    /// are accumulated. Missing maternal or offspring genotypes are tallied as
    /// missing and excluded from the frequencies.
    public func pollenPool(forFamily family: MaternalFamily, atLocus locusIndex: Int) -> PollenPoolFrequencies {
        let column = columns[locusIndex]
        var pool = PollenPoolFrequencies(codebook: column.codebook)
        let motherAlleles = family.mother.flatMap { column.alleles(at: $0) } ?? (0, 0)
        for offspringOrdinal in family.offspring {
            let offspringAlleles = column.alleles(at: offspringOrdinal) ?? (0, 0)
            pool.add(offspring: offspringAlleles, mother: motherAlleles)
        }
        return pool
    }

    /// The pollen pool a single mother sampled, one ``PollenPoolFrequencies`` per
    /// locus in ordinal order.
    public func pollenPool(forFamily family: MaternalFamily) -> [PollenPoolFrequencies] {
        (0..<locusCount).map { pollenPool(forFamily: family, atLocus: $0) }
    }
}
