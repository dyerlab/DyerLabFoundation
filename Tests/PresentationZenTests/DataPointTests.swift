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
//  DataPointTests.swift
//
//
//  Created by Rodney Dyer on 3/29/24.
//

import Foundation
import Testing
@testable import PresentationZen

@Suite("DataPoint")
struct DataPointTests {

    @Test("x/y initializer sets all fields")
    func xyInit() {
        let pt = DataPoint(x: 3.0, y: 7.5, label: "A", group: "G1", category: "C1")
        #expect(pt.xValue == 3.0)
        #expect(pt.yValue == 7.5)
        #expect(pt.label == "A")
        #expect(pt.grouping == "G1")
        #expect(pt.category == "C1")
        #expect(pt.date == nil)
    }

    @Test("category/value initializer sets xValue equal to value")
    func categoryInit() {
        let pt = DataPoint(category: "Cat", value: 5.0)
        #expect(pt.category == "Cat")
        #expect(pt.yValue == 5.0)
        #expect(pt.xValue == 5.0)
    }

    @Test("temporal initializer sets date and value")
    func temporalInit() {
        let now = Date.now
        let pt = DataPoint(time: now, value: 1.0)
        #expect(pt.date == now)
        #expect(pt.yValue == 1.0)
    }

    @Test("Comparable sorts by xValue when no date present")
    func sortByX() {
        let pts = [DataPoint(x: 3, y: 0), DataPoint(x: 1, y: 0), DataPoint(x: 2, y: 0)]
        let sorted = pts.sorted()
        #expect(sorted.map(\.xValue) == [1, 2, 3])
    }

    @Test("Comparable sorts by date when present")
    func sortByDate() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let pts = [
            DataPoint(time: base.addingTimeInterval(200), value: 0),
            DataPoint(time: base.addingTimeInterval(100), value: 0),
            DataPoint(time: base, value: 0)
        ]
        let sorted = pts.sorted()
        #expect(sorted[0].date == base)
        #expect(sorted[2].date == base.addingTimeInterval(200))
    }
}

@Suite("Array<DataPoint> extensions")
struct ArrayDataPointTests {

    let data: [DataPoint] = [
        DataPoint(x: 1.0, y: 10.0, category: "A"),
        DataPoint(x: 2.0, y: 20.0, category: "A"),
        DataPoint(x: 3.0, y: 30.0, category: "B"),
        DataPoint(x: 4.0, y: 40.0, category: "B"),
    ]

    @Test("minimum returns element-wise min of x and y")
    func minimum() {
        let mn = data.minimum
        #expect(mn.xValue == 1.0)
        #expect(mn.yValue == 10.0)
    }

    @Test("maximum returns element-wise max of x and y")
    func maximum() {
        let mx = data.maximum
        #expect(mx.xValue == 4.0)
        #expect(mx.yValue == 40.0)
    }

    @Test("yMean computes average of yValues")
    func yMean() {
        #expect(data.yMean == 25.0)
    }

    @Test("yMean returns nan for empty array")
    func yMeanEmpty() {
        #expect([DataPoint]().yMean.isNaN)
    }

    @Test("isEmpty is false for non-empty array regardless of yValues")
    func isEmptyNonEmpty() {
        let zeros = [DataPoint(x: 1, y: 0), DataPoint(x: 2, y: 0)]
        #expect(!zeros.isEmpty)
    }

    @Test("isEmpty is true only for empty array")
    func isEmptyEmpty() {
        #expect([DataPoint]().isEmpty)
    }

    @Test("yMean returns 0 for array with all-zero yValues")
    func yMeanAllZeros() {
        let zeros = [DataPoint(x: 1, y: 0), DataPoint(x: 2, y: 0)]
        #expect(zeros.yMean == 0.0)
    }

    @Test("minimum on empty array returns infinity sentinels")
    func minimumEmpty() {
        let mn = [DataPoint]().minimum
        #expect(mn.xValue == .infinity)
        #expect(mn.yValue == .infinity)
    }

    @Test("maximum on empty array returns negative-infinity sentinels")
    func maximumEmpty() {
        let mx = [DataPoint]().maximum
        #expect(mx.xValue == -.infinity)
        #expect(mx.yValue == -.infinity)
    }

    @Test("histogram produces non-empty bins for non-empty input")
    func histogram() {
        let bins = data.histogram(numBins: 4)
        #expect(!bins.isEmpty)
    }

    @Test("histogram returns empty for empty input")
    func histogramEmpty() {
        #expect([DataPoint]().histogram().isEmpty)
    }

    @Test("histogram handles all-identical yValues without infinite loop")
    func histogramAllIdentical() {
        let pts = [DataPoint(x: 0, y: 5), DataPoint(x: 1, y: 5), DataPoint(x: 2, y: 5)]
        let bins = pts.histogram(numBins: 10)
        #expect(bins.count == 3)
        #expect(bins[1].yValue == 3)
    }

    @Test("frequencyDistribution silently drops values outside range")
    func frequencyDistributionOutOfRange() {
        let pts = [DataPoint(x: 0, y: 0), DataPoint(x: 0, y: 6), DataPoint(x: 0, y: 3)]
        let freq = pts.frequencyDistribution(range: 1...5)
        #expect(freq.map(\.yValue).reduce(0, +) == 1)  // only y=3 is in range
    }

    @Test("frequencyDistribution counts values per integer bucket")
    func frequencyDistribution() {
        let pts = [
            DataPoint(x: 0, y: 1),
            DataPoint(x: 0, y: 2),
            DataPoint(x: 0, y: 2),
            DataPoint(x: 0, y: 3),
            DataPoint(x: 0, y: 5),
        ]
        let freq = pts.frequencyDistribution(range: 1...5)
        #expect(freq.count == 5)
        #expect(freq.first(where: { $0.category == "2" })?.yValue == 2)
        #expect(freq.first(where: { $0.category == "4" })?.yValue == 0)
    }

    @Test("trendlinePoints spans from minimum to maximum x")
    func trendlinePoints() {
        let pts = data.trendlinePoints(intercept: 0, slope: 1)
        #expect(pts.count == 2)
        #expect(pts[0].xValue == 1.0)
        #expect(pts[1].xValue == 4.0)
    }

    @Test("trendlinePoints y values satisfy y = slope*x + intercept")
    func trendlineValues() {
        let slope = 2.5
        let intercept = 3.0
        let pts = data.trendlinePoints(intercept: intercept, slope: slope)
        #expect(abs(pts[0].yValue - (slope * 1.0 + intercept)) < 0.0001)
        #expect(abs(pts[1].yValue - (slope * 4.0 + intercept)) < 0.0001)
    }
}

@Suite("Array<Double> extensions")
struct ArrayDoubleTests {

    @Test("sum")
    func sum() {
        #expect([1.0, 2.0, 3.0, 4.0].sum() == 10.0)
    }

    @Test("mean")
    func mean() {
        #expect([2.0, 4.0, 6.0].mean() == 4.0)
    }

    @Test("median even count")
    func medianEven() {
        #expect([1.0, 2.0, 3.0, 4.0].median() == 2.5)
    }

    @Test("median odd count")
    func medianOdd() {
        #expect([1.0, 2.0, 3.0].median() == 2.0)
    }

    @Test("sample standard deviation")
    func standardDeviation() {
        // [0, 2, 4]: mean=2, sum-sq-dev=8, sd=sqrt(8/2)=2
        #expect(abs([0.0, 2.0, 4.0].sd() - 2.0) < 0.0001)
    }

    @Test("discretize counts occurrences per value")
    func discretize() {
        let d = [1.0, 2.0, 1.0, 3.0, 2.0, 1.0].discretize
        #expect(d[1.0] == 3)
        #expect(d[2.0] == 2)
        #expect(d[3.0] == 1)
    }
}
