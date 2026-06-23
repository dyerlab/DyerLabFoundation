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
//  DataTableTests.swift
//

import Foundation
import Testing
@testable import Matrix
@testable import PresentationZen

@Suite("PlotValue")
struct PlotValueTests {

    @Test("accessors return the wrapped value only for the matching kind")
    func accessors() {
        #expect(PlotValue.number(3).doubleValue == 3)
        #expect(PlotValue.number(3).dateValue == nil)
        #expect(PlotValue.category("A").stringValue == "A")
        #expect(PlotValue.category("A").doubleValue == nil)
        let now = Date.now
        #expect(PlotValue.date(now).dateValue == now)
    }
}

@Suite("DataTable roles & resolution")
struct DataTableTests {

    private func sample() -> DataTable {
        DataTable(numbers: ["x": [1, 2, 3], "y": [10, 20, 30]],
                  strings: ["g": ["A", "A", "B"], "lab": ["p", "q", "r"]])
    }

    @Test("fluent role assignment is immutable and records column names")
    func rolesFluent() {
        let t = sample().x("x").y("y").series("g").label("lab")
        #expect(t.column(for: .x) == "x")
        #expect(t.column(for: .y) == "y")
        #expect(t.column(for: .series) == "g")
        #expect(t.column(for: .label) == "lab")
        // Original table is untouched (value semantics).
        #expect(sample().column(for: .x) == nil)
    }

    @Test("plotRows resolves a numeric x with series and skips when roles missing")
    func plotRowsNumeric() {
        let t = sample().x("x").y("y").series("g")
        let rows = t.plotRows
        #expect(rows.count == 3)
        #expect(rows[0].x == .number(1))
        #expect(rows[0].y == 10)
        #expect(rows[0].series == "A")
        #expect(t.xKind == .number)
        #expect(t.seriesValues == ["A", "B"])
        #expect(sample().plotRows.isEmpty)   // no x/y roles bound
    }

    @Test("plotRows resolves a categorical x")
    func plotRowsCategorical() {
        let t = DataTable(numbers: ["y": [5, 6]], strings: ["c": ["L", "M"]]).x("c").y("y")
        #expect(t.xKind == .category)
        #expect(t.plotRows.first?.x == .category("L"))
    }

    @Test("plotRows resolves a temporal x")
    func plotRowsDate() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let t = DataTable(numbers: ["y": [1, 2]],
                          dates: ["d": [base, base.addingTimeInterval(86_400)]]).x("d").y("y")
        #expect(t.xKind == .date)
        #expect(t.plotRows.first?.x == .date(base))
    }

    @Test("plotRows skips rows whose y is non-finite")
    func skipsNonFiniteY() {
        let t = DataTable(numbers: ["x": [1, 2], "y": [Double.nan, 5]]).x("x").y("y")
        #expect(t.plotRows.count == 1)
        #expect(t.plotRows.first?.y == 5)
    }
}

@Suite("DataTable ↔ Matrix bridge")
struct DataTableMatrixTests {

    @Test("init(matrix:) maps columns and binds a label role")
    func fromMatrix() {
        let m = Matrix(2, 2, Vector([1, 2, 3, 4]))
        m.rowNames = ["r0", "r1"]
        m.colNames = ["c0", "c1"]
        let t = DataTable(matrix: m)
        #expect(t.rowCount == 2)
        #expect(t.column("c0") == [1, 3])
        #expect(t.column("c1") == [2, 4])
        #expect(t.column(for: .label) == "Label")
    }

    @Test("asMatrix round-trips numeric columns and carries row labels")
    func toMatrix() {
        let t = DataTable(numbers: ["a": [1, 2], "b": [3, 4]],
                          strings: ["Label": ["r0", "r1"]],
                          roles: [.label: "Label"])
        let m = t.asMatrix(["a", "b"])
        #expect(m.rows == 2)
        #expect(m.cols == 2)
        #expect(m[0, 0] == 1)
        #expect(m[0, 1] == 3)
        #expect(m[1, 0] == 2)
        #expect(m[1, 1] == 4)
        #expect(m.rowNames == ["r0", "r1"])
        #expect(m.colNames == ["a", "b"])
    }

    @Test("init(vector:) builds a single y-bound column")
    func vectorInit() {
        let t = DataTable(vector: Vector([1, 2, 3]), name: "v")
        #expect(t.column("v") == [1, 2, 3])
        #expect(t.column(for: .y) == "v")
    }
}

@Suite("DataTable transforms")
struct DataTableTransformTests {

    @Test("histogram counts sum to sample size with x/y roles pre-set")
    func histogram() {
        let t = DataTable(numbers: ["v": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]], roles: [.y: "v"])
        let h = t.histogram(of: "v", bins: 5)
        #expect(h.column(for: .x) == "bin")
        #expect(h.column(for: .y) == "count")
        #expect(h.rowCount == 5)
        #expect(h.column("count").reduce(0, +) == 10)
    }

    @Test("histogram of identical values collapses to one bin")
    func histogramIdentical() {
        let t = DataTable(numbers: ["v": [5, 5, 5]], roles: [.y: "v"])
        #expect(t.histogram(bins: 10).rowCount == 1)
    }

    @Test("frequency buckets a column and drops out-of-range values")
    func frequency() {
        let t = DataTable(numbers: ["v": [1, 2, 2, 3, 3, 3, 9]], roles: [.y: "v"])
        let f = t.frequency(range: 1...5)
        #expect(f.rowCount == 5)
        #expect(f.column("count") == [1, 2, 3, 0, 0])
        #expect(f.xKind == .category)
    }

    @Test("collapsed(by:.year) sums per year and drops undated rows implicitly")
    func collapsedByYear() {
        var c = DateComponents()
        c.day = 1
        c.year = 2024; c.month = 7
        let jul24 = Calendar.current.date(from: c)!
        c.month = 10
        let oct24 = Calendar.current.date(from: c)!
        c.year = 2025; c.month = 3
        let mar25 = Calendar.current.date(from: c)!

        let t = DataTable(numbers: ["v": [10, 5, 7]],
                          dates: ["d": [jul24, oct24, mar25]],
                          roles: [.x: "d", .y: "v"])
        let g = t.collapsed(by: .year)
        #expect(g.rowCount == 2)
        #expect(g.column("period") == [2024, 2025])
        #expect(g.column("total") == [15, 7])
    }

    @Test("trendline spans the x range and satisfies y = slope*x + intercept")
    func trendline() {
        let t = DataTable(numbers: ["x": [1, 2, 3, 4], "y": [0, 0, 0, 0]],
                          roles: [.x: "x", .y: "y"])
        let rows = t.trendline(intercept: 3, slope: 2.5).plotRows
        #expect(rows.count == 2)
        #expect(rows[0].x == .number(1))
        #expect(rows[1].x == .number(4))
        #expect(abs(rows[0].y - (2.5 * 1 + 3)) < 0.0001)
        #expect(abs(rows[1].y - (2.5 * 4 + 3)) < 0.0001)
    }

    @Test("boxSummary computes per-category median")
    func boxSummary() {
        let t = DataTable(numbers: ["y": [10, 20, 30, 100, 200, 300]],
                          strings: ["c": ["A", "A", "A", "B", "B", "B"]],
                          roles: [.x: "c", .y: "y"])
        let boxes = t.boxSummary()
        #expect(boxes.count == 2)
        #expect(boxes.first(where: { $0.category == "A" })?.median == 20)
        #expect(boxes.first(where: { $0.category == "B" })?.median == 200)
    }
}

@Suite("Array<Double> extensions")
struct ArrayDoubleTests {

    @Test("sum")
    func sum() { #expect([1.0, 2.0, 3.0, 4.0].sum() == 10.0) }

    @Test("mean")
    func mean() { #expect([2.0, 4.0, 6.0].mean() == 4.0) }

    @Test("median even count")
    func medianEven() { #expect([1.0, 2.0, 3.0, 4.0].median() == 2.5) }

    @Test("median odd count")
    func medianOdd() { #expect([1.0, 2.0, 3.0].median() == 2.0) }

    @Test("sample standard deviation")
    func standardDeviation() {
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
