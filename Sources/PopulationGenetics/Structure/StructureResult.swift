//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureResult.swift
//  PopulationGenetics
//
//  A structure table as values: the variance components of one statistic, or
//  the statistics locus by locus with the multilocus ratios of sums last.
//  Column names stay valid R names; `columnHeaders` gives the symbols shown.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix
import PresentationZen
import TabularData

/// The table and report of a ``StructureAnalysis``.
public struct StructureResult: Sendable, Equatable {

    /// The name of a by-locus table's column of flagged statistics.
    public static let concernColumn = "Warning"

    /// Headers to show instead of the table's column names, which stay valid R names.
    public static let columnHeaders: [String: String] = {
        var headers = ["Phi_ST": "Φ_ST", "sigma2": "σ²"]
        for column in StructureSpec.Column.allCases {
            headers[column.name] = column.header
            headers["P_" + column.name] = "P (\(column.header))"
        }
        return headers
    }()

    /// The parameters it ran with.
    public let spec: StructureSpec

    /// A variance-components table's sources, outermost first and ending with the total; empty by locus.
    public let rows: [StructureTableRow]

    /// A by-locus table's rows, the multilocus row last when there is more than one locus; empty otherwise.
    public let locusRows: [StructureLocusRow]

    /// The statistic a test follows: the variance-components statistic, or a by-locus table's first tested
    /// column over all its loci.
    public let statistic: Double?

    /// Its permutation probability, if it was tested.
    public let pValue: Double?

    /// Remarks under the table, such as which loci have a flagged statistic.
    public let warnings: [String]

    /// The Methods and Results text, with every decision made about the data, for the project log.
    public let report: AnalysisReport

    /// The followed statistic's permutation null distribution, or `nil` if it wasn't tested.
    public let distribution: NullDistributionResult?

    /// Creates a result.
    ///
    /// - Parameters:
    ///   - spec: The parameters it ran with.
    ///   - rows: A variance-components table's sources.
    ///   - locusRows: A by-locus table's rows.
    ///   - statistic: The followed statistic.
    ///   - pValue: Its permutation probability.
    ///   - warnings: Remarks under the table.
    ///   - report: The analysis's report.
    ///   - distribution: The followed statistic's null distribution, if it was tested.
    public init(spec: StructureSpec, rows: [StructureTableRow] = [], locusRows: [StructureLocusRow] = [],
                statistic: Double?, pValue: Double?, warnings: [String] = [], report: AnalysisReport,
                distribution: NullDistributionResult? = nil) {
        self.spec = spec
        self.rows = rows
        self.locusRows = locusRows
        self.statistic = statistic
        self.pValue = pValue
        self.warnings = warnings
        self.report = report
        self.distribution = distribution
    }

    // MARK: - Table

    /// The table.
    ///
    /// A variance-components table has `Source`, `df`, `SS`, `MS`, `sigma2`, the statistic and, if tested, `P`.
    /// A by-locus table has `Locus`, `N`, `Alleles`, `Hs` and `Ht` (adults), each column with its `P_` column
    /// after it if tested, and `Warning` if any statistic is flagged. Empty cells are missing values.
    public var dataTable: DataTable {
        var frame = DataFrame()
        switch spec.table {
        case .amova:
            frame.append(column: TabularData.Column(name: "Source", contents: rows.map(\.source)))
            frame.append(column: TabularData.Column(name: "df", contents: rows.map(\.df)))
            frame.append(column: TabularData.Column(name: "SS", contents: rows.map(\.ss)))
            frame.append(column: TabularData.Column(name: "MS", contents: rows.map(\.ms)))
            frame.append(column: TabularData.Column(name: "sigma2", contents: rows.map(\.sigma)))
            frame.append(column: TabularData.Column(name: spec.statistic.columnName, contents: rows.map(\.statistic)))
            if spec.isTested { frame.append(column: TabularData.Column(name: "P", contents: rows.map(\.p))) }
        case .perLocus:
            frame.append(column: TabularData.Column(name: "Locus", contents: locusRows.map(\.locus)))
            frame.append(column: TabularData.Column(name: "N", contents: locusRows.map(\.units)))
            frame.append(column: TabularData.Column(name: "Alleles", contents: locusRows.map(\.alleles)))
            if spec.sample == .adults {
                frame.append(column: TabularData.Column(name: "Hs", contents: locusRows.map(\.hs)))
                frame.append(column: TabularData.Column(name: "Ht", contents: locusRows.map(\.ht)))
            }
            let tested = spec.isTested ? spec.testedColumns : []
            for (c, column) in spec.columns.enumerated() {
                frame.append(column: TabularData.Column(name: column.name, contents: locusRows.map { $0.values[c] }))
                if let t = tested.firstIndex(of: column) {
                    frame.append(column: TabularData.Column(name: "P_" + column.name,
                                                            contents: locusRows.map { t < $0.p.count ? $0.p[t] : nil }))
                }
            }
            if locusRows.contains(where: { !$0.concerns.isEmpty }) {
                frame.append(column: TabularData.Column(name: Self.concernColumn, contents: locusRows.map { row in
                    row.concerns.isEmpty ? "" : "⚠︎ " + row.concerns.joined(separator: "; ")
                }))
            }
        }
        return DataTable(frame: frame)
    }

    // MARK: - Legend

    /// A legend for the table, saying what was analysed and how, and any flagged statistics.
    public var legend: String {
        let groups = StructureSpec.plural(spec.level)
        let loci = spec.locus.map { "locus \($0)" } ?? "all loci"
        var text: String
        switch spec.table {
        case .amova:
            text = "\(spec.statistic.title) among \(groups) at \(loci). \(spec.statistic.summary)"
            if spec.locus == nil {
                text += " The multilocus value is the ratio of the variance components summed over loci."
            }
        case .perLocus:
            let units = spec.sample == .adults ? "individuals" : "paternal gametes"
            text = "Differentiation among \(groups) at \(loci). N is the number of \(units) genotyped at the locus "
                + "and Alleles the number seen there."
            if spec.sample == .adults {
                text += " Hs and Ht are \(spec.heterozygosity.methods)."
            }
            text += " " + spec.columns.map(\.definition).joined(separator: "; ") + "."
            if locusRows.count > 1 {
                text += " The multilocus row divides each statistic's numerator and denominator summed over loci, "
                    + "rather than averaging the loci; its Hs and Ht are means."
            }
        }
        if spec.isTested {
            text += " P is the proportion of \(AnalysisReport.count(spec.permutations)) permutations reaching the "
                + "observed value."
        }
        for warning in warnings { text += " ⚠︎ " + warning }
        return text
    }
}
