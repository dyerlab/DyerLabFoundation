//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MantelAnalysis.swift
//  Matrix
//
//  A port of vegan's `mantel()`. The predictor's rows and columns are
//  permuted together, as vegan permutes its first argument, with draws from
//  `RMersenneTwister`: `MantelAnalysis(response: y, predictor: x)` run with
//  seed `s` reproduces `set.seed(s); mantel(x, y)` permutation by
//  permutation, for `n ≥ 8` units (below that, vegan enumerates every
//  permutation instead of sampling).
//
//  Pairs whose response is not finite are left out, so a conditional genetic
//  distance matrix with `Inf` between disconnected populations can be used
//  directly; this is how gstudio's `ibgd(mode = "cgd")` restricts its test.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// A Mantel test between two square matrices over the same units
/// (``AnalysisType/mantel``).
///
/// The statistic is the correlation between the matrices' entries over the
/// unit pairs `i < j`; both matrices are taken to be symmetric. Its
/// significance is the one-sided proportion of permutations, plus one, whose
/// correlation is at least the observed value.
public struct MantelAnalysis: Analysis {

    /// ``AnalysisType/mantel``.
    public static let analysisType: AnalysisType = .mantel

    /// The response matrix, e.g. genetic distance.
    public let response: [[Double]]

    /// The predictor matrix, e.g. spatial separation; this one is permuted.
    public let predictor: [[Double]]

    /// The units' names, in matrix order.
    public let names: [String]

    /// The correlation coefficient.
    public let method: CorrelationMethod

    /// The label for the outcome.
    public let tag: AnalysisTag

    /// What the response matrix holds, for the report (e.g. "genetic distance").
    public var responseLabel = "the response distances"

    /// What the predictor matrix holds, for the report (e.g. "geographic distance").
    public var predictorLabel = "the predictor distances"

    /// What the units are, plural, for the report (e.g. "populations").
    public var unitLabel = "units"

    /// The pairs `(i, j)`, `i < j`, with a finite response.
    private let pairs: [(Int, Int)]

    /// The number of pairs the test uses (pairs with a finite response).
    public var pairCount: Int { pairs.count }

    /// Creates the analysis.
    ///
    /// - Parameters:
    ///   - response: An `n × n` matrix; pairs with a non-finite value are left out.
    ///   - predictor: An `n × n` matrix in the same unit order, finite off the diagonal.
    ///   - names: The units' names, in matrix order, or `nil` (default) to
    ///     number them from `1`.
    ///   - method: The correlation coefficient (default `.pearson`).
    ///   - tag: The outcome's label (default `AnalysisType.mantel.tag`).
    /// - Returns: `nil` if the matrices are not square and the same size, the
    ///   predictor has a non-finite off-diagonal entry, `names` is the wrong
    ///   length, or fewer than three pairs have a finite response.
    public init?(response: [[Double]],
                 predictor: [[Double]],
                 names: [String]? = nil,
                 method: CorrelationMethod = .pearson,
                 tag: AnalysisTag = AnalysisType.mantel.tag) {
        let n = response.count
        guard predictor.count == n, names.map({ $0.count == n }) ?? true,
              response.allSatisfy({ $0.count == n }),
              predictor.allSatisfy({ $0.count == n }) else { return nil }

        var pairs: [(Int, Int)] = []
        for j in 0..<n {
            for i in 0..<j {
                guard predictor[i][j].isFinite, predictor[j][i].isFinite else { return nil }
                if response[i][j].isFinite { pairs.append((i, j)) }
            }
        }
        guard pairs.count >= 3 else { return nil }

        self.response = response
        self.predictor = predictor
        self.names = names ?? (1...n).map(String.init)        // n ≥ 3 here
        self.method = method
        self.tag = tag
        self.pairs = pairs
    }

    /// Correlates the matrices and, if `options.iterations > 0`, tests the
    /// correlation by permuting the predictor's units.
    ///
    /// - Parameter options: Permutation count and seed (R's `set.seed()` value).
    /// - Returns: The statistic and its null distribution; never `nil`.
    public func run(options: AnalysisOptions) -> MantelOutcome? {
        run(options: options) { _, _ in true }
    }

    /// Correlates the matrices and tests the correlation, reporting each permuted value as it is drawn.
    ///
    /// The permutations are the same as ``run(options:)`` draws for the same seed.
    ///
    /// - Parameters:
    ///   - options: Permutation count and seed (R's `set.seed()` value).
    ///   - observing: Called after each permutation with the number done and the permuted correlation; return
    ///     `false` to stop.
    /// - Returns: The statistic and its null distribution, or `nil` if `observing` stopped the test.
    public func run(options: AnalysisOptions, observing: (_ done: Int, _ value: Double) -> Bool) -> MantelOutcome? {
        let y = pairs.map { response[$0.0][$0.1] }
        let x = pairs.map { predictor[$0.0][$0.1] }
        let observed = method.correlation(x, y)

        var distribution: NullDistributionResult?
        if options.iterations > 0 {
            var rng = RMersenneTwister(seed: Int(truncatingIfNeeded: options.seed))
            var values: [Double] = []
            values.reserveCapacity(options.iterations)
            for done in 1...options.iterations {
                let order = rng.sampleIndicesNoReplacement(n: response.count)     // R: sample.int(n)
                let value = method.correlation(pairs.map { predictor[order[$0.0]][order[$0.1]] }, y)
                values.append(value)
                guard observing(done, value) else { return nil }
            }
            distribution = NullDistributionResult(analysisType: tag, observed: observed,
                                                  values: values, seed: options.seed)
        }
        let points = zip(pairs, zip(x, y)).map { pair, value in
            PairwisePoint(from: names[pair.0], to: names[pair.1], x: value.0, y: value.1)
        }
        return MantelOutcome(tag: tag, method: method, r: observed, points: points,
                             line: RegressionLine(leastSquaresOf: y, on: x), distribution: distribution)
    }
}
