//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  mateGenotypes.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//

/// Produces one offspring allele pair by randomly selecting one allele from
/// each parent's genotype, lexicographically ordered, with lineage tagged by
/// which side each allele came from.
///
/// Pure and storage-independent — the caller (`PopGenStore.mateIndividuals`,
/// `randomMate`) is responsible for writing the result into a store.
///
/// - Returns: `nil` if either parent's genotype has no alleles to draw from.
public func mateGenotypes(mother motherGenotype: Genotype, father fatherGenotype: Genotype)
-> (leftAllele: String, rightAllele: String, leftLineage: Int, rightLineage: Int)? {
    guard let lAllele = [motherGenotype.leftAllele, motherGenotype.rightAllele].randomElement(),
          let rAllele = [fatherGenotype.leftAllele, fatherGenotype.rightAllele].randomElement() else {
        return nil
    }

    if lAllele < rAllele {
        return (leftAllele: lAllele, rightAllele: rAllele,
                leftLineage: Genotype.MaternalLineage, rightLineage: Genotype.PaternalLineage)
    } else {
        return (leftAllele: rAllele, rightAllele: lAllele,
                leftLineage: Genotype.PaternalLineage, rightLineage: Genotype.MaternalLineage)
    }
}
