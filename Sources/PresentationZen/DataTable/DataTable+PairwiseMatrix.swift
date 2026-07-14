//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  DataTable+PairwiseMatrix.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/13/26.
//

import Matrix

extension DataTable {

    /// Joins any number of pairwise measures over the same groups into one
    /// long-format table — one row per unordered group pair, `GroupA`/
    /// `GroupB` name columns, plus one numeric column per matrix (named via
    /// each matrix's `columnName`).
    ///
    /// Adding a new pairwise measure (relatedness, a structure statistic,
    /// least-cost/circuitscape ecological distance, ...) never touches this
    /// function — define its `PairwiseMeasure` marker, get a
    /// `DistanceMatrix<Kind>` for it, and pass it in alongside the others.
    ///
    /// - Parameter matrices: One or more pairwise matrices; every matrix
    ///   must share the exact same `groupNames` (same set, same order) and a
    ///   distinct `columnName` — mismatched groups aren't reconciled here,
    ///   since silently realigning rows risks mislabeling a pair.
    public init(pairwise matrices: [any PairwiseMatrix]) {
        precondition(!matrices.isEmpty, "DataTable(pairwise:): at least one matrix required")
        let groupNames = matrices[0].groupNames
        precondition(matrices.allSatisfy { $0.groupNames == groupNames },
                     "DataTable(pairwise:): all matrices must share the same groupNames")
        let columnNames = matrices.map(\.columnName)
        precondition(Set(columnNames).count == columnNames.count,
                     "DataTable(pairwise:): matrices must have distinct columnName values")

        var groupA: [String] = []
        var groupB: [String] = []
        var numbers: [String: [Double]] = Dictionary(uniqueKeysWithValues: columnNames.map { ($0, []) })

        for i in 0..<groupNames.count {
            for j in (i + 1)..<groupNames.count {
                groupA.append(groupNames[i])
                groupB.append(groupNames[j])
                for matrix in matrices {
                    numbers[matrix.columnName]!.append(matrix[i, j])
                }
            }
        }

        self.init(numbers: numbers, strings: ["GroupA": groupA, "GroupB": groupB])
    }
}
