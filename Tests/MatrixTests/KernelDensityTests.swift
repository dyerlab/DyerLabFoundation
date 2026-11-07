//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  KernelDensityTests.swift
//  MatrixTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import Matrix

struct KernelDensityTests {

    /// Compares with values from `Fixtures/generate_kernel_density.R` (R 4.5.3).
    ///
    /// The bandwidth and grid are exact, but R bins the data and uses an FFT, so densities agree
    /// only to within 0.001.
    @Test func matchesR() throws {
        let values = [0.10, 0.20, 0.20, 0.30, 0.50, 0.80, 0.85, 0.40, 0.45, 0.05]
        #expect(abs(SilvermanBandwidth(values) - 0.121835979764) < 1e-11)

        let curve = KernelDensity(values, points: 512)
        let indices = [0, 63, 127, 191, 255, 319, 383, 447, 511]
        let x = [-0.315507939293, -0.126752557002, 0.064998942469, 0.256750441940, 0.448501941410,
                 0.640253440881, 0.832004940352, 1.023756439822, 1.215507939293]
        let density = [0.004710328122, 0.191037086291, 1.054833655982, 1.417430386850, 1.180404615657,
                       0.533217947631, 0.651122227297, 0.179180281844, 0.004623965733]
        for (position, index) in indices.enumerated() {
            #expect(abs(curve[index].x - x[position]) < 1e-9)
            #expect(abs(curve[index].density - density[position]) < 1e-3)
        }
    }

    @Test func bandwidthMatchesRsRuleOfThumb() {
        // R: bw.nrd0(1:5), where IQR / 1.34 is smaller than the standard deviation.
        let expected = 0.9 * (2.0 / 1.34) * pow(5.0, -0.2)
        #expect(abs(SilvermanBandwidth([1, 2, 3, 4, 5]) - expected) < 1e-12)
    }

    @Test func bandwidthFallsBackWhenThereIsNoSpread() {
        #expect(abs(SilvermanBandwidth([2, 2, 2]) - 0.9 * 2 * pow(3.0, -0.2)) < 1e-12)
        #expect(abs(SilvermanBandwidth([0, 0]) - 0.9 * pow(2.0, -0.2)) < 1e-12)
    }

    @Test func densityIntegratesToAboutOne() throws {
        let curve = KernelDensity([0.1, 0.2, 0.2, 0.3, 0.5, 0.8], points: 512)
        let step = try #require(curve.dropFirst().first?.x) - (try #require(curve.first?.x))
        let area = curve.reduce(0) { $0 + $1.density * step }
        #expect(abs(area - 1) < 0.01)
    }

    @Test func densityOfIdenticalValuesIsFinite() {
        #expect(KernelDensity([0, 0, 0]).allSatisfy { $0.density.isFinite })
        #expect(KernelDensity([]).isEmpty)
    }
}
