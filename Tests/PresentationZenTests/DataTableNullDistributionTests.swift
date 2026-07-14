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
//  New coverage — DataTable(nullDistribution:) is new code (no prior
//  version existed in PopulationGenetics to port from).
//

import Foundation
import Testing
@testable import Matrix
@testable import PresentationZen

struct DataTableNullDistributionTests {

    @Test func binsIntoRequestedBinCount() async throws {
        let result = NullDistributionResult(analysisType: AnalysisTag("test"), observed: 5.0,
                                             values: (1...100).map(Double.init))
        let table = DataTable(nullDistribution: result, bins: 10)
        #expect(table.rowCount == 10)
    }

    @Test func setsXYRoles() async throws {
        let result = NullDistributionResult(analysisType: AnalysisTag("test"), observed: 5.0,
                                             values: [1, 2, 3, 4, 5])
        let table = DataTable(nullDistribution: result, bins: 5)
        #expect(table.roles[.x] == "value")
        #expect(table.roles[.y] == "count")
    }

    @Test func countsSumToTotalValues() async throws {
        let values = (1...50).map(Double.init)
        let result = NullDistributionResult(analysisType: AnalysisTag("test"), observed: 1.0, values: values)
        let table = DataTable(nullDistribution: result, bins: 8)
        let counts = Array(table.frame["count", Double.self]).map { $0! }
        #expect(counts.reduce(0, +) == Double(values.count))
    }
}
