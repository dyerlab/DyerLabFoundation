//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  BORICEResult.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/23/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Foundation

extension BORICE {

    public struct Result {
        public let samples: [State]
        
        public var meanT: Double {
            samples.map(\.t).reduce(0.0, +) / Double(samples.count)
        }
        
        public var meanF: Double {
            let totalF = samples.flatMap { state in
                state.inbreedingHistories.map { ih in
                    ih >= 6 ? 1.0 : 1.0 - pow(0.5, Double(ih))
                }
            }
            return totalF.reduce(0.0, +) / Double(totalF.count)
        }
        
        public func posteriorIH() -> [Double] {
            var counts = [Int](repeating: 0, count: 7)
            let totalIH = samples.flatMap(\.inbreedingHistories)
            for ih in totalIH {
                counts[ih] += 1
            }
            return counts.map { Double($0) / Double(totalIH.count) }
        }

        public func credibleIntervalT(percentile: Double = 0.95) -> (Double, Double) {
            let sortedT = samples.map(\.t).sorted()
            let lowerIdx = Int(Double(sortedT.count) * (1.0 - percentile) / 2.0)
            let upperIdx = Int(Double(sortedT.count) * (1.0 + percentile) / 2.0)
            return (sortedT[lowerIdx], sortedT[upperIdx])
        }
        
        public func summary() -> String {
            var s = "BORICE Analysis Summary\n"
            s += "=======================\n"
            s += String(format: "Mean Outcrossing Rate (t): %.4f\n", meanT)
            let (tLow, tHigh) = credibleIntervalT()
            s += String(format: "95%% Credible Interval (t): [%.4f, %.4f]\n", tLow, tHigh)
            s += String(format: "Mean Inbreeding Coeff (F): %.4f\n", meanF)
            s += "\nPosterior Distribution of Inbreeding History (IH):\n"
            let ihDist = posteriorIH()
            for (ih, prob) in ihDist.enumerated() {
                s += String(format: "  IH %d: %.4f\n", ih, prob)
            }
            return s
        }
    }
}

extension GenotypeMatrix {

    public func runBORICE(
        design: ParentageDesign,
        parameters: BORICE.Parameters = BORICE.Parameters(),
        hasNullModel: [Bool]? = nil
    ) -> BORICE.Result {
        let sampler = BORICE.Sampler(matrix: self, design: design, parameters: parameters, hasNullModel: hasNullModel)
        let samples = sampler.run()
        return BORICE.Result(samples: samples)
    }
}
