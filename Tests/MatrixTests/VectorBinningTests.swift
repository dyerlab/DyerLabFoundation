//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  VectorBinningTests.swift
//

import Foundation
import Testing

@testable import Matrix

@Suite("Vector binning")
struct VectorBinningTests {

    @Test("Histogram counts sum to the sample size")
    func histogramTotals() {
        let v = Vector([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        let bins = v.histogram(bins: 5)
        #expect(bins.count == 5)
        #expect(bins.map(\.count).reduce(0, +) == v.count)
    }

    @Test("Histogram includes the maximum in the final bin")
    func histogramIncludesMax() {
        let v = Vector([0, 10])
        let bins = v.histogram(bins: 2)
        #expect(bins.count == 2)
        #expect(bins.map(\.count).reduce(0, +) == 2)
        #expect(bins.last?.count == 1)   // the value 10 lands in the last bin
    }

    @Test("Zero-variance data yields a single bin holding everything")
    func histogramIdentical() {
        let v = Vector([4, 4, 4, 4])
        let bins = v.histogram(bins: 10)
        #expect(bins.count == 1)
        #expect(bins.first?.count == 4)
    }

    @Test("Empty vector yields no bins")
    func histogramEmpty() {
        #expect(Vector().histogram(bins: 8).isEmpty)
    }

    @Test("Frequency counts each integer bucket and drops out-of-range values")
    func frequencyBuckets() {
        let v = Vector([1, 1, 2, 3, 3, 3, 9])   // 9 is out of range
        let counts = v.frequency(range: 1...5)
        #expect(counts == [2, 1, 3, 0, 0])
    }
}
