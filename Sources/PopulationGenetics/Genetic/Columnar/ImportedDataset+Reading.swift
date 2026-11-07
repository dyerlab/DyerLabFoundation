//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ImportedDataset+Reading.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension ImportedDataset {

    /// Whether any individual belongs to a population.
    ///
    /// Without populations there is nothing to build a population graph from.
    public var hasPopulations: Bool {
        strata.values.contains { !$0.isEmpty }
    }

    /// The population (innermost stratum) of an individual.
    ///
    /// - Parameter ordinal: The individual's row in `matrix`.
    /// - Returns: The population's name, or `""` if the individual has no strata.
    public func populationName(at ordinal: Int) -> String {
        strata[matrix.individuals[ordinal].id]?.last?.name ?? ""
    }

    /// The allele labels of one genotype, in canonical (sorted) order.
    ///
    /// - Parameters:
    ///   - ordinal: The individual's row in `matrix`.
    ///   - locus: The locus's index in `matrix`.
    /// - Returns: The two allele labels, or `nil` for missing data.
    public func alleleLabels(at ordinal: Int, locus: Int) -> (String, String)? {
        let column = matrix.columns[locus]
        guard let (left, right) = column.alleles(at: ordinal) else { return nil }
        return (column.codebook.label(for: left), column.codebook.label(for: right))
    }
}
