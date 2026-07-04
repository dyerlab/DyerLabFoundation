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
//  FiguresTablesTests.swift
//
//
//  Created by Rodney Dyer on 2026-02-24.

import Foundation
import Testing
@testable import PresentationZen

@Suite("BoxSummary")
struct BoxSummaryTests {

    @Test("computes median and sd per category")
    func basicStats() {
        let t = DataTable(numbers: ["v": [10, 20, 30]],
                          strings: ["c": ["A", "A", "A"]],
                          roles: [.x: "c", .y: "v"])
        let boxes = t.boxSummary()
        #expect(boxes.count == 1)
        #expect(boxes[0].category == "A")
        #expect(boxes[0].median == 20.0)
        #expect(abs(boxes[0].sd - 10.0) < 0.0001)
    }

    @Test("empty table yields no summaries")
    func emptyInput() {
        let t = DataTable(numbers: ["v": []], strings: ["c": []], roles: [.x: "c", .y: "v"])
        #expect(t.boxSummary().isEmpty)
    }

    @Test("single-value category has nan sd")
    func singlePoint() {
        let t = DataTable(numbers: ["v": [42]],
                          strings: ["c": ["X"]],
                          roles: [.x: "c", .y: "v"])
        let boxes = t.boxSummary()
        #expect(boxes.count == 1)
        #expect(boxes[0].median == 42.0)
        #expect(boxes[0].sd.isNaN)
    }
}

@Suite("dateRegression")
struct DateRegressionTests {

    private func table(_ pairs: [(Date, Double)]) -> DataTable {
        DataTable(numbers: ["v": pairs.map(\.1)],
                  dates: ["d": pairs.map(\.0)],
                  roles: [.x: "d", .y: "v"])
    }

    @Test("returns nil for fewer than 2 dated points")
    func tooFewPoints() {
        #expect(dateRegression(table([(.now, 1.0)])) == nil)
    }

    @Test("returns nil when the x role is not a date column")
    func noDateRole() {
        let t = DataTable(numbers: ["x": [1, 2], "y": [1, 2]], roles: [.x: "x", .y: "y"])
        #expect(dateRegression(t) == nil)
    }

    @Test("fits positive slope to a linearly ascending series")
    func positiveTrend() throws {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let t = table((0..<5).map { (base.addingTimeInterval(Double($0) * 86_400), Double($0) * 2.0) })
        let result = try #require(dateRegression(t))
        #expect(result.slope > 0)
        #expect(result.r2 > 0.99)
        #expect(result.fitted.count == 5)
    }

    @Test("slope is negative for a descending series")
    func negativeTrend() throws {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let t = table((0..<5).map { (base.addingTimeInterval(Double($0) * 86_400), Double(4 - $0) * 3.0) })
        let result = try #require(dateRegression(t))
        #expect(result.slope < 0)
    }

    @Test("averages multiple points sharing the same date")
    func duplicateDates() throws {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let t = table([(base, 10.0), (base, 20.0), (base.addingTimeInterval(86_400), 30.0)])
        let result = try #require(dateRegression(t))
        #expect(result.fitted.count == 2)   // two unique dates
        #expect(abs(result.fitted[0].y - 15.0) < 0.0001)
    }

    @Test("flat y-series produces zero slope and NaN r2")
    func flatSeries() throws {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let t = table((0..<4).map { (base.addingTimeInterval(Double($0) * 86_400), 5.0) })
        let result = try #require(dateRegression(t))
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
        let fitted = [PlotRow(id: 0, x: .number(0), y: 0),
                      PlotRow(id: 1, x: .number(1), y: 1)]
        let r = RegressionResult(slope: 1.0, intercept: 0.0, r2: 1.0, fitted: fitted)
        #expect(!r.isEmpty)
    }

    @Test("summary exposes the coefficients as a coefficient/value DataTable")
    func summaryTable() {
        let r = RegressionResult(slope: 2.0, intercept: -1.5, r2: 0.9, fitted: [])
        let table = r.summary
        #expect(table.rowCount == 3)
        #expect(table.stringColumn("coefficient") == ["slope", "intercept", "rSquared"])
        #expect(table.numericColumn("value").compactMap { $0 } == [2.0, -1.5, 0.9])
        #expect(table.column(for: .x) == "coefficient")
        #expect(table.column(for: .y) == "value")
    }
}
