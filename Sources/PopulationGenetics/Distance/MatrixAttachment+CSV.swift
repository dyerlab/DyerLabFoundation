//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MatrixAttachment+CSV.swift
//  PopulationGenetics
//
//  A stored matrix as CSV, in the layout `MatrixHeatmapData.csvText` writes.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen

public extension MatrixAttachment {

    /// The matrix as CSV text, with row and column names.
    ///
    /// - Returns: The CSV.
    /// - Throws: A `DecodingError` when the data isn't an encoded `Matrix`.
    func csvText() throws -> String {
        try heatmapData().csvText
    }

    /// The matrix as a CSV file named for it.
    ///
    /// - Returns: The file.
    /// - Throws: A `DecodingError` when the data isn't an encoded `Matrix`.
    func csvFile() throws -> PlotExportFile {
        try heatmapData().csvFile(named: name)
    }
}
