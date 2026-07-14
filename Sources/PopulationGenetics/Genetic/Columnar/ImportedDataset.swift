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
//  Created by Rodney Dyer on 6/28/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
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

    public init(matrix: GenotypeMatrix, parentage: ParentageDesign, strata: [UUID: [StratumReference]] = [:]) {
        self.matrix = matrix
        self.parentage = parentage
        self.strata = strata
    }
}
