//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MantelAnalysis+PairwiseMatrix.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

extension MantelAnalysis {

    /// Creates a Mantel test between two named pairwise matrices, matching
    /// units by name (e.g. a `PhiSTMatrix` against a great-circle `SpatialMatrix`).
    ///
    /// - Parameters:
    ///   - response: The response matrix; its group order is used.
    ///   - predictor: The predictor matrix, over the same group names in any order.
    ///   - method: The correlation coefficient (default `.pearson`).
    ///   - tag: The outcome's label (default `AnalysisType.mantel.tag`).
    /// - Returns: `nil` if the two matrices do not name the same groups, or for
    ///   any reason ``init(response:predictor:names:method:tag:)`` gives.
    public init?(response: any PairwiseMatrix,
                 predictor: any PairwiseMatrix,
                 method: CorrelationMethod = .pearson,
                 tag: AnalysisTag = AnalysisType.mantel.tag) {
        let names = response.groupNames
        guard Set(names) == Set(predictor.groupNames), Set(names).count == names.count else { return nil }
        let index = Dictionary(uniqueKeysWithValues: predictor.groupNames.enumerated().map { ($1, $0) })
        let order = names.map { index[$0]! }
        let n = names.count
        self.init(response: (0..<n).map { i in (0..<n).map { j in response[i, j] } },
                  predictor: (0..<n).map { i in (0..<n).map { j in predictor[order[i], order[j]] } },
                  names: names,
                  method: method,
                  tag: tag)
    }
}
