//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StrataRarefactionAnalysis+Report.swift
//  PopulationGenetics
//
//  Manuscript text for diversity rarefied among strata: how subsamples were
//  drawn, and each statistic's multilocus range of rarefied estimates across
//  strata (or each locus's, with one locus).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension StrataRarefactionAnalysis {

    /// The Methods and Results wording.
    public static var reportTemplate: AnalysisReportTemplate {
        AnalysisReportTemplate(
            methods: "To compare {strataLabel} of different size, {statistics} were rarefied: at each of {loci} "
                + "loci, every {stratumLabel} was subsampled without replacement to {sizeRule}, {iterations} "
                + "times (random seed {seed}), and each statistic was summarised by its mean and central {coverage} "
                + "percentile interval over subsamples.{multilocus}",
            results: "{summaries}")
    }

    /// The Methods values.
    ///
    /// - Parameter options: The options the analysis ran with.
    /// - Returns: The values for ``reportTemplate``'s Methods text.
    public func methodsValues(options: AnalysisOptions) -> [String: String] {
        let stratumLabel = level.map { $0.lowercased() } ?? "sample"
        return [
            "strataLabel": level == nil ? "samples" : "\(strata.count) \(stratumLabel) strata",
            "stratumLabel": stratumLabel,
            "statistics": Self.list(statistics.map(\.name)),
            "loci": AnalysisReport.count(loci.count),
            "sizeRule": size.map { "\(AnalysisReport.count($0)) genotyped individuals" }
                ?? "the number genotyped in the smallest \(stratumLabel) at that locus",
            "iterations": AnalysisReport.count(options.iterations),
            "seed": String(options.seed),
            "coverage": "\(AnalysisReport.number(confidenceLevel * 100))%",
            "multilocus": loci.count > 1
                ? " Multilocus values were taken draw by draw: the mean over loci, except Fis as 1 − ΣHo/ΣHe and "
                    + "Pex as 1 − Π(1 − Pex)" + (dropsMissingLoci ? ", leaving out loci without a value." : ".")
                : "",
        ]
    }

    /// The report for a finished run.
    ///
    /// - Parameters:
    ///   - rows: The rows.
    ///   - shortCells: The cells too small to rarefy.
    ///   - options: The options it ran with.
    /// - Returns: The Methods and Results text, with the notes.
    func report(rows: [StrataRarefactionRow], shortCells: [String], options: AnalysisOptions) -> AnalysisReport {
        let template = Self.reportTemplate
        let summaryLocus: String? = loci.count > 1 ? nil : rows.first?.locus
        let summaries = statistics.map { statistic -> String in
            let estimates = rows.filter { $0.statistic == statistic && $0.locus == summaryLocus }
                .compactMap { row in row.estimate.map { (row.stratum, $0) } }
            guard let low = estimates.min(by: { $0.1 < $1.1 }), let high = estimates.max(by: { $0.1 < $1.1 }) else {
                return "\(statistic.name) could not be rarefied."
            }
            return "Rarefied \(summaryLocus == nil ? "multilocus " : "")\(statistic.name) ranged from "
                + "\(AnalysisReport.number(low.1)) (\(low.0)) to \(AnalysisReport.number(high.1)) (\(high.0))."
        }
        var notes: [AnalysisNote] = [
            AnalysisNote(.assumption, "Diversity was estimated from the adults; offspring were left out."),
        ]
        if !shortCells.isEmpty {
            notes.append(AnalysisNote(.warning, "Too few genotypes to rarefy, so no value: "
                                      + shortCells.joined(separator: ", ") + "."))
        }
        let methods = AnalysisReportTemplate.fill(template.methods, with: methodsValues(options: options))
        let results = AnalysisReportTemplate.fill(template.results, with: ["summaries": summaries.joined(separator: " ")])
        return AnalysisReport(analysisType: .rarefaction, tag: .strataRarefaction, options: options,
                              methods: methods, results: results, notes: notes)
    }

    /// "a", "a and b", "a, b and c".
    private static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
    }
}
