//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AMOVA+GeneticDistance.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.06.28.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

extension AMOVA {
    /// Builds an AMOVA directly from a genetic distance matrix.
    ///
    /// - Parameter distance: Pairwise squared genetic distances among individuals.
    public init(distance: GeneticDistanceMatrix) {
        self.init(squaredDistances: distance.dense())
    }
}
