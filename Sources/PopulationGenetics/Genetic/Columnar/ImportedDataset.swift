//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ImportedDataset.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.06.28.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The result of importing a genotype table.
public struct ImportedDataset: Sendable {
    /// The genotype matrix parsed from the CSV (individuals × loci).
    public var matrix: GenotypeMatrix
    /// The parentage design describing maternal families and offspring.
    public var parentage: ParentageDesign
    /// Each individual's hierarchical stratum lineage (e.g. Region > Population),
    /// keyed by `Individual.id`. Empty for imports with no strata metadata.
    public var strata: [UUID: [StratumReference]]

    /// Creates a dataset.
    ///
    /// - Parameters:
    ///   - matrix: The genotype matrix.
    ///   - parentage: The parentage design.
    ///   - strata: Each individual's stratum lineage, keyed by `Individual.id` (default none).
    public init(matrix: GenotypeMatrix, parentage: ParentageDesign, strata: [UUID: [StratumReference]] = [:]) {
        self.matrix = matrix
        self.parentage = parentage
        self.strata = strata
    }
}
