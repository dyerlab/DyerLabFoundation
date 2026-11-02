//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisType+Graph.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension AnalysisType {

    /// Isolation by graph distance: conditional genetic distance (cGD) through
    /// a population graph against separation, with a Mantel test
    /// (gstudio's `ibgd(mode = "cgd")`).
    public static let isolationByGraphDistance =
        AnalysisType("isolationByGraphDistance",
                     displayName: "Isolation by Graph Distance",
                     operands: [AnalysisOperand(role: "graph", kind: .graph),
                                AnalysisOperand(role: "separation", kind: .pairwise)],
                     usesIterations: true)

    /// Directional isolation by graph distance: directed partitioned genetic
    /// distance (pGD) against separation with forward and reverse slopes,
    /// compared with cGD (gstudio's `ibgd(mode = "pgd")`).
    public static let directionalIsolationByGraphDistance =
        AnalysisType("directionalIsolationByGraphDistance",
                     displayName: "Directional Isolation by Graph Distance",
                     operands: [AnalysisOperand(role: "graph", kind: .graph),
                                AnalysisOperand(role: "separation", kind: .pairwise)],
                     usesIterations: false)
}
