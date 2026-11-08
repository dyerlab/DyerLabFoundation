//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MatrixAttachment+Heatmap.swift
//  PopulationGenetics
//
//  A stored matrix, or one just computed, as the heatmap draws it. A stored
//  distance matrix gets its units from its spec; a matrix from anywhere else
//  (such as R) is drawn as it is, without groups or units.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import PresentationZen

public extension MatrixAttachment {

    /// What the matrix holds, when it is a distance matrix.
    var distanceSpec: DistanceSpec? {
        DistanceSpec(json: spec)
    }

    /// The matrix as a heatmap draws it.
    ///
    /// - Parameter groups: Each row's group, such as an individual's population, or `nil`.
    /// - Returns: The heatmap data.
    /// - Throws: A `DecodingError` when the data isn't an encoded `Matrix`.
    func heatmapData(groups: [String]? = nil) throws -> MatrixHeatmapData {
        let matrix = try JSONDecoder().decode(Matrix.self, from: data)
        return MatrixHeatmapData(matrix, groups: groups, units: distanceSpec?.measure.units)
    }
}

public extension DistanceResult {

    /// The matrix as a heatmap draws it, with each individual's group.
    var heatmapData: MatrixHeatmapData {
        let names = matrix.groupNames
        return MatrixHeatmapData(rowNames: names, columnNames: names, values: matrix.dense().flatMap { $0 },
                                 groups: groups, units: spec.measure.units)
    }
}
