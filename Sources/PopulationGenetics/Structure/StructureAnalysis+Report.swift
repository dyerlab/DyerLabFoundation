//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureAnalysis+Report.swift
//  PopulationGenetics
//
//  The Methods and Results a structure table writes to the log, worded as its
//  legend and the controls' description are, with the data decisions and any
//  flagged statistics as notes.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension StructureAnalysis {

    /// What was analysed, for Methods: `"363 individuals in 39 populations at 8 loci"`.
    private var sampleClause: String {
        let units = spec.sample == .adults ? "individuals" : "paternal gametes"
        let loci = spec.locus.map { "locus \($0)" } ?? "\(AnalysisReport.count(locusCount)) loci"
        return "\(AnalysisReport.count(unitCount)) \(units) in \(AnalysisReport.count(strataCount)) "
            + "\(StructureSpec.plural(spec.level)) at \(loci)"
    }

    /// The permutation sentence, for Methods.
    private var permutationSentence: String {
        let units = spec.sample == .adults ? "individuals" : "paternal gametes"
        return AnalysisReport.permutationSentence(options, permuting: "whole \(units) among "
                                                  + StructureSpec.plural(spec.level))
    }

    /// The analysis type the table reports.
    private var analysisType: AnalysisType {
        switch (spec.table, spec.statistic) {
        case (.perLocus, _): .geneticDifferentiation
        case (.amova, .theta): .weirCockerham
        case (.amova, _): .amova
        }
    }

    /// The report of a variance-components table.
    ///
    /// - Parameters:
    ///   - rows: The table's rows.
    ///   - parts: The analysis of variance, summed over loci.
    ///   - p: The statistic's permutation probability, if tested.
    /// - Returns: The report.
    func report(rows: [StructureTableRow], parts: VarianceParts, p: Double?) -> AnalysisReport {
        let statistic = spec.statistic
        var methods = "Genetic structure among \(sampleClause) was estimated as \(statistic.title). "
            + statistic.summary + " Each locus used the individuals genotyped there"
        methods += spec.locus == nil && locusCount > 1
            ? ", and the multilocus value is the ratio of the variance components summed over loci. "
            : ". "
        methods += permutationSentence
        let n = AnalysisReport.number
        let results: String
        if statistic == .theta {
            results = "θ = \(n(rows[0].statistic ?? .nan)) (\(AnalysisReport.pValue(p))), F_IS = "
                + "\(n(rows[1].statistic ?? .nan)) and F_IT = \(n(rows[3].statistic ?? .nan)) (σ²_among = "
                + "\(n(parts.sigma[0])), σ²_individuals = \(n(parts.sigma[1])), σ²_within = \(n(parts.sigma[2])))."
        } else {
            results = "Φ_ST = \(n(parts.amongShare)) (\(AnalysisReport.pValue(p))); σ²_among = "
                + "\(n(parts.sigma[0])) and σ²_within = \(n(parts.sigma[1]))."
        }
        var notes = self.notes
        if spec.locus == nil, parts.df.contains(where: { $0 == nil }) {
            notes.append(AnalysisNote(.assumption, "The loci were genotyped in different numbers of individuals, so "
                                      + "the summed table gives no single df or mean square; its sums of squares "
                                      + "and variance components are summed over loci."))
        }
        return AnalysisReport(analysisType: analysisType, tag: tag, options: options, methods: methods,
                              results: results, notes: notes)
    }

    /// The report of a by-locus table.
    ///
    /// - Parameters:
    ///   - rows: The table's rows, the multilocus row last.
    ///   - warnings: The flagged statistics.
    /// - Returns: The report.
    func report(rows: [StructureLocusRow], warnings: [String]) -> AnalysisReport {
        var methods = "Differentiation among \(sampleClause) was estimated locus by locus from allele counts, each "
            + "locus using the units genotyped there: " + spec.columns.map(\.definition).joined(separator: "; ")
            + "."
        if spec.sample == .adults {
            methods += " Hs and Ht are \(spec.heterozygosity.methods)."
        }
        if rows.count > 1 {
            methods += " Multilocus values divide each statistic's numerator and denominator summed over loci, rather "
                + "than averaging the per-locus values."
        }
        methods += " " + permutationSentence
        let n = AnalysisReport.number
        let summary = rows.last
        let tested = spec.isTested ? spec.testedColumns : []
        let values = spec.columns.enumerated().map { c, column -> String in
            var text = "\(column.header) = \(n(summary?.values[c] ?? .nan))"
            if let t = tested.firstIndex(of: column), let p = summary?.p[t] { text += " (\(AnalysisReport.pValue(p)))" }
            return text
        }
        let scope = rows.count > 1 ? "Over all loci" : "At \(summary?.locus ?? "the locus")"
        let results = "\(scope), " + values.joined(separator: ", ") + "."
        let notes = self.notes + warnings.map { AnalysisNote(.warning, $0 + " The values are reported as estimated.") }
        return AnalysisReport(analysisType: analysisType, tag: tag, options: options, methods: methods,
                              results: results, notes: notes)
    }
}
