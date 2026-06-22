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
//  ExtensionsTests.swift
//
//
//  Created by Rodney Dyer on 2026-02-24.


import Foundation
import Testing
@testable import PresentationZen

@Suite("BoxPlotPoint")
struct BoxPlotPointTests {

    @Test("computes median and sd from DataPoints grouped by category")
    func basicStats() {
        let pts = [
            DataPoint(category: "A", value: 10.0),
            DataPoint(category: "A", value: 20.0),
            DataPoint(category: "A", value: 30.0),
        ]
        let box = BoxPlotPoint(points: pts)
        #expect(box.category == "A")
        #expect(box.median == 20.0)
        #expect(abs(box.sd - 10.0) < 0.0001)
    }

    @Test("uses 'undefined' category and nan stats for empty input")
    func emptyInput() {
        let box = BoxPlotPoint(points: [])
        #expect(box.category == "undefined")
        #expect(box.median.isNaN)
        #expect(box.sd.isNaN)
    }

    @Test("single-point input has nan sd")
    func singlePoint() {
        let box = BoxPlotPoint(points: [DataPoint(category: "X", value: 42.0)])
        #expect(box.category == "X")
        #expect(box.median == 42.0)
        #expect(box.sd.isNaN)
    }
}

@Suite("dateRegression")
struct DateRegressionTests {

    @Test("returns nil for fewer than 2 dated points")
    func tooFewPoints() {
        let pt = DataPoint(time: .now, value: 1.0)
        #expect(dateRegression(data: [pt]) == nil)
    }

    @Test("returns nil when no points have a date")
    func noDatePoints() {
        let pts = [DataPoint(x: 1, y: 1), DataPoint(x: 2, y: 2)]
        #expect(dateRegression(data: pts) == nil)
    }

    @Test("fits positive slope to linearly ascending series")
    func positiveTrend() throws {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let pts = (0..<5).map { i in
            DataPoint(time: base.addingTimeInterval(Double(i) * 86400), value: Double(i) * 2.0)
        }
        let result = try #require(dateRegression(data: pts))
        #expect(result.slope > 0)
        #expect(result.r2 > 0.99)
        #expect(result.fitted.count == 5)
    }

    @Test("slope is negative for descending series")
    func negativeTrend() throws {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let pts = (0..<5).map { i in
            DataPoint(time: base.addingTimeInterval(Double(i) * 86400), value: Double(4 - i) * 3.0)
        }
        let result = try #require(dateRegression(data: pts))
        #expect(result.slope < 0)
    }

    @Test("averages multiple points sharing the same date")
    func duplicateDates() throws {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let pts = [
            DataPoint(time: base, value: 10.0),
            DataPoint(time: base, value: 20.0),           // same date → averaged to 15
            DataPoint(time: base.addingTimeInterval(86400), value: 30.0),
        ]
        let result = try #require(dateRegression(data: pts))
        #expect(result.fitted.count == 2)   // two unique dates
        #expect(abs(result.fitted[0].yValue - 15.0) < 0.0001)
    }

    @Test("flat y-series produces zero slope and NaN r2")
    func flatSeries() throws {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let pts = (0..<4).map { i in
            DataPoint(time: base.addingTimeInterval(Double(i) * 86400), value: 5.0)
        }
        let result = try #require(dateRegression(data: pts))
        #expect(abs(result.slope) < 0.0001)
        #expect(result.r2.isNaN)
    }
}

@Suite("RegressionResult")
struct RegressionResultTests {

    @Test("default initializer produces empty, nan-filled result")
    func defaultInit() {
        let r = RegressionResult()
        #expect(r.isEmpty)
        #expect(r.slope.isNaN)
        #expect(r.intercept.isNaN)
        #expect(r.r2.isNaN)
    }

    @Test("isEmpty is false when fitted points are provided")
    func nonEmpty() {
        let fitted = [DataPoint(x: 0, y: 0), DataPoint(x: 1, y: 1)]
        let r = RegressionResult(slope: 1.0, intercept: 0.0, r2: 1.0, fitted: fitted)
        #expect(!r.isEmpty)
    }
}
