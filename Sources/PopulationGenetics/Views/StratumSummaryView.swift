//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StratumSummaryView.swift
//  PopulationGenetics
//
//  The stratum counterpart of `FamilySummaryView`, drawn above the stratum's genotypes so a population can be read,
//  and its data checked, one at a time.
//
//  Created by Rodney Dyer on 2026.11.09.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// One stratum at a glance: where it sits and is, who is in it, and each locus's diversity among its adults.
public struct StratumSummaryView: View {
    /// The stratum's summary.
    public let report: StratumReport

    /// Creates a stratum's summary.
    ///
    /// - Parameter report: The stratum's summary.
    public init(report: StratumReport) {
        self.report = report
    }

    // MARK: - Body

    /// The summary.
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        Text(report.offspringCount > 0 ? "Mothers" : "Individuals").foregroundStyle(.secondary)
                        Text(report.adults.count, format: .number)
                    }
                    if report.offspringCount > 0 {
                        GridRow {
                            Text("Offspring").foregroundStyle(.secondary)
                            Text(report.offspringCount, format: .number)
                        }
                    }
                    GridRow {
                        Text("With coordinates").foregroundStyle(.secondary)
                        Text(report.locatedCount, format: .number)
                    }
                }
                lociTable
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(report.name)
                .font(.title2.bold())
            Text(placeText)
                .foregroundStyle(.secondary)
        }
    }

    private var lociTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(report.offspringCount > 0 ? "Diversity among the mothers" : "Diversity")
                .font(.headline)
            Grid(alignment: .trailing, horizontalSpacing: 18, verticalSpacing: 4) {
                GridRow {
                    ForEach(Self.headers, id: \.self) { Text($0).bold() }
                }
                Divider()
                ForEach(report.loci) { row($0) }
                Divider()
                row(report.multilocus)
                    .bold()
            }
            .font(.callout.monospacedDigit())
            Text("A: alleles · Ae: effective alleles · F = 1 − Ho / He; Multilocus F = 1 − ΣHo / ΣHe.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// The locus table's column headers.
    private static let headers = ["Locus", "N", "A", "Ae", "Ho", "He", "F"]

    /// One locus's row.
    ///
    /// - Parameter locus: The locus's values.
    /// - Returns: The row.
    private func row(_ locus: StratumReport.LocusRow) -> some View {
        GridRow {
            Text(locus.locus).gridColumnAlignment(.leading)
            Text(locus.genotyped, format: .number)
            Text(format(locus.alleles, digits: locus.locus == "Multilocus" ? 2 : 0))
            Text(format(locus.effectiveAlleles, digits: 2))
            Text(format(locus.ho, digits: 3))
            Text(format(locus.he, digits: 3))
            Text(format(locus.f, digits: 3))
        }
    }

    // MARK: - Text

    /// The level, the strata the stratum sits within, and its centre.
    private var placeText: String {
        var parts = [report.level]
        if !report.parents.isEmpty { parts[0] += " in " + report.parents.joined(separator: " › ") }
        if let latitude = report.latitude, let longitude = report.longitude {
            parts.append(String(format: "%.5f, %.5f", latitude, longitude))
        }
        return parts.joined(separator: " · ")
    }

    /// A value to a number of decimals, or a dash when missing.
    ///
    /// - Parameters:
    ///   - value: The value.
    ///   - digits: The decimals shown.
    /// - Returns: The text.
    private func format(_ value: Double?, digits: Int) -> String {
        guard let value, value.isFinite else { return "–" }
        return value.formatted(.number.precision(.fractionLength(digits)))
    }
}

// MARK: - Previews

#Preview("Araptus population") {
    if let dataset = try? ExampleDataset.arapatPopulations.load(),
       let name = StratumReport.strata(of: "Population", in: dataset).first {
        StratumSummaryView(report: StratumReport(dataset: dataset, level: "Population", name: name))
            .frame(width: 600, height: 500)
    }
}
