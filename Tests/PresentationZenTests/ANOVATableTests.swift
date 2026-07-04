//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Created by Rodney Dyer on 7/4/26.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import Matrix
@testable import PresentationZen

@Suite("anovaTable")
struct ANOVATableTests {

    @Test("row labels and order are Model, Residual, Total")
    func rowLabels() throws {
        let table = DataTable(numbers: ["v": [1, 2, 3, 10, 12]],
                              strings: ["g": ["A", "A", "A", "B", "B"]],
                              roles: [.x: "g", .y: "v"])
        let anova = try #require(anovaTable(table))
        #expect(anova.stringColumn("source") == ["Model", "Residual", "Total"])
    }

    @Test("one-way ANOVA from a DataTable matches hand-computed SS/df/F")
    func oneWayFromDataTable() throws {
        // Two groups: A = [1, 2, 3], B = [10, 12] — same example verified by
        // hand against LinearModelFitTests' oneWayAnovaFromDesignMatrixMatchesHandComputedValues.
        let table = DataTable(numbers: ["v": [1, 2, 3, 10, 12]],
                              strings: ["g": ["A", "A", "A", "B", "B"]],
                              roles: [.x: "g", .y: "v"])
        let anova = try #require(anovaTable(table))

        let df = anova.numericColumn("df").compactMap { $0 }
        let ss = anova.numericColumn("ss").compactMap { $0 }
        let ms = anova.numericColumn("ms").compactMap { $0 }
        let f = anova.numericColumn("f").compactMap { $0 }

        #expect(df == [1, 3, 4])
        #expect(abs(ss[0] - 97.2) < 1e-9)
        #expect(abs(ss[1] - 4.0) < 1e-9)
        #expect(abs(ss[2] - 101.2) < 1e-9)
        #expect(abs(ms[0] - 97.2) < 1e-9)
        #expect(abs(ms[1] - (4.0 / 3.0)) < 1e-9)
        #expect(ms[2].isNaN)
        #expect(abs(f[0] - 72.9) < 1e-6)
        #expect(f[1].isNaN)
        #expect(f[2].isNaN)
    }

    @Test("nil when x role isn't categorical")
    func nonCategoricalXReturnsNil() {
        let table = DataTable(numbers: ["x": [1, 2, 3], "v": [1, 2, 3]], roles: [.x: "x", .y: "v"])
        #expect(anovaTable(table) == nil)
    }

    @Test("nil when roles are missing")
    func missingRolesReturnsNil() {
        let table = DataTable(numbers: ["v": [1, 2, 3]], strings: ["g": ["A", "B", "C"]])
        #expect(anovaTable(table) == nil)
    }

    @Test("RegressionResult overload round-trips through dateRegression")
    func regressionOverloadRoundTrips() throws {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        let table = DataTable(numbers: ["v": (0..<5).map { Double($0) * 2.0 }],
                              dates: ["d": (0..<5).map { base.addingTimeInterval(Double($0) * 86_400) }],
                              roles: [.x: "d", .y: "v"])
        let result = try #require(dateRegression(table))
        let anova = try #require(anovaTable(result))

        #expect(anova.stringColumn("source") == ["Model", "Residual", "Total"])
        let f = anova.numericColumn("f").compactMap { $0 }
        #expect(f[0] > 0)
    }

    @Test("nil for a RegressionResult built without a fit")
    func regressionOverloadNilWithoutFit() {
        #expect(anovaTable(RegressionResult()) == nil)
    }

    @Test("PermutationTestResult overload adds a p column, NaN off the Model row")
    func permutationOverloadAddsPColumn() throws {
        let X = Matrix.DesignMatrix(strata: ["A", "A", "A", "B", "B"])
        let result = try #require(permutationTest(designMatrix: X, response: [1, 2, 3, 10, 12], permutations: 99))

        let anova = anovaTable(result)
        #expect(anova.stringColumn("source") == ["Model", "Residual", "Total"])
        let p = anova.numericColumn("p").compactMap { $0 }
        #expect(p[0] > 0 && p[0] <= 1)
        #expect(p[1].isNaN)
        #expect(p[2].isNaN)
    }

    @Test("nullDistributionTable has one row per permutation with a y-bound msA column")
    func nullDistributionTableShape() throws {
        let X = Matrix.DesignMatrix(strata: ["A", "A", "A", "B", "B"])
        let result = try #require(permutationTest(designMatrix: X, response: [1, 2, 3, 10, 12], permutations: 99))

        let table = nullDistributionTable(result)
        #expect(table.rowCount == 99)
        #expect(table.column(for: .y) == "msA")
    }
}
