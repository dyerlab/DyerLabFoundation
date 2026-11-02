//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisOperandKind+PopulationGenetics.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension AnalysisOperandKind {

    /// Individuals' genotypes: one locus (`[Genotype]`) or many (`GenotypeMatrix`).
    public static let genotypes = AnalysisOperandKind("genotypes")

    /// Maternal families of mothers and their offspring (`ParentageDesign`).
    public static let families = AnalysisOperandKind("families")
}
