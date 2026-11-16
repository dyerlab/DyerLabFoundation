//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMatrix+MultilocusDiversity.swift
//  PopulationGenetics
//
//  Multilocus genotypic diversity, gstudio's `genetic_diversity(mode = "Dm")`:
//  the number of distinct multilocus genotypes over the number of
//  individuals. As in gstudio, a missing genotype is a value like any other,
//  so two individuals differ if one is missing where the other is scored, and
//  allele order within a genotype doesn't matter.
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

public extension GenotypeMatrix {

    /// The fraction of individuals with distinct multilocus genotypes (`DiversityType.Dm`).
    ///
    /// - Parameters:
    ///   - ordinals: The individuals' rows, or `nil` (the default) for every individual.
    ///   - loci: The locus ordinals, or `nil` (the default) for every locus.
    /// - Returns: The distinct multilocus genotypes over the individuals, or `nil` when there are no individuals
    ///   or no loci.
    func multilocusDiversity(over ordinals: [Int]? = nil, loci: [Int]? = nil) -> Double? {
        let rows = ordinals ?? Array(individuals.indices)
        let used = loci ?? Array(self.loci.indices)
        guard !rows.isEmpty, !used.isEmpty else { return nil }
        var distinct: Set<[UInt8]> = []
        for row in rows {
            var key: [UInt8] = []
            key.reserveCapacity(2 * used.count)
            for j in used {
                let (a, b) = columns[j].alleles(at: row) ?? (0, 0)
                key.append(min(a, b))
                key.append(max(a, b))
            }
            distinct.insert(key)
        }
        return Double(distinct.count) / Double(rows.count)
    }
}
