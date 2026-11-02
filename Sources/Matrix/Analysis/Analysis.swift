//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Analysis.swift
//  Matrix
//
//  An `Analysis` value holds its validated operands, so it is `Sendable` and
//  can be handed to a background task; building it is where unusable input
//  is caught (a failable `init`). Following the Swift Coding Protocol,
//  analyses return `nil` on input they can't run on rather than throwing.
//
//  Every analysis also reports itself: a Methods/Results template with
//  `{key}` placeholders, the Methods values drawn from its data and options,
//  and the notes recording decisions made about the data. `perform(options:)`
//  runs the analysis and fills the template, so a log gets manuscript-ready
//  text for every run.
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// An analysis technique bound to its operands, ready to run.
public protocol Analysis: Sendable {

    /// The outcome this analysis produces.
    associatedtype Outcome: AnalysisOutcome

    /// The technique this analysis implements.
    static var analysisType: AnalysisType { get }

    /// The label for this analysis's outcome. Defaults to the technique's own
    /// tag; a conformer may take a domain label instead (e.g. Φ_ST).
    var tag: AnalysisTag { get }

    /// Runs the analysis.
    ///
    /// - Parameter options: Iteration count and seed.
    /// - Returns: The outcome, or `nil` if the analysis cannot run with these
    ///   options (e.g. too few iterations for rarefaction).
    func run(options: AnalysisOptions) -> Outcome?

    // MARK: - Reporting

    /// The default Methods and Results text for this technique.
    static var reportTemplate: AnalysisReportTemplate { get }

    /// The values for the Methods placeholders, drawn from the data and
    /// options (sample sizes, the number of groups, the permutations run).
    ///
    /// - Parameter options: The options the analysis runs with.
    /// - Returns: A value for each Methods key.
    func methodsValues(options: AnalysisOptions) -> [String: String]

    /// Decisions made about the data while building the analysis (values
    /// dropped or imputed). Defaults to none.
    var notes: [AnalysisNote] { get }
}

extension Analysis {

    /// The technique this analysis implements.
    public var analysisType: AnalysisType { Self.analysisType }

    /// The technique's default tag.
    public var tag: AnalysisTag { Self.analysisType.tag }

    /// No notes by default.
    public var notes: [AnalysisNote] { [] }
}
