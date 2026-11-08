//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IBDSpec+Table.swift
//  PopulationGenetics
//
//  An isolation-by-distance analysis's statistics as a two-column table,
//  built from the spec's results, so a saved analysis shows and exports the
//  same table it did when it ran.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen
import TabularData

public extension IBDSpec {

    /// The statistics: pairs, the Mantel r, P and permutations when tested, then the regression's slope,
    /// intercept and R²; `nil` before the test has run.
    var resultsTable: DataTable? {
        guard let result else { return nil }
        var rows: [(String, Double?)] = [("Pairs", Double(result.pairs)),
                                         ("Mantel r (\(method.displayName))", result.r)]
        if isTested {
            rows.append(("P", result.p))
            rows.append(("Permutations", Double(permutations)))
        }
        rows += [("Slope", result.slope), ("Intercept", result.intercept), ("R²", result.r2)]
        var frame = DataFrame()
        frame.append(column: TabularData.Column(name: "Statistic", contents: rows.map(\.0)))
        frame.append(column: TabularData.Column(name: "Value", contents: rows.map(\.1)))
        return DataTable(frame: frame)
    }
}
