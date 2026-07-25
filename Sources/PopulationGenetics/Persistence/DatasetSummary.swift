//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DatasetSummary.swift
//  PopulationGenetics
//
//  A cheap, file-level classification of a persisted `ProjectStore` file's
//  contents, read straight from the `meta` table (see
//  `ProjectStore+Summary.swift`) with no genotype/graph/result decoding.
//  Intended for callers that need to classify a file — e.g. an "Open Recent"
//  list choosing an icon for parentage vs. non-parentage, SNP vs.
//  microsatellite, graph-only vs. genetic-data — without paying for
//  `readDataset()`.
//
//  Project-level fields (`projectName`/`species`/`description`/`createdAt`)
//  are always present, written unconditionally at `create` time regardless
//  of which components a file holds. Every other field is optional: `nil`
//  means the component isn't present in this file at all (as opposed to
//  present with no data yet, which reads as `false`/`0`).
//

import Foundation

/// A cheap, file-level summary of what a persisted `ProjectStore` file contains.
public struct DatasetSummary: Sendable, Equatable {

    /// Which marker type(s) the file's loci use.
    public enum MarkerComposition: String, Sendable, Equatable {
        /// Every locus is a biallelic SNP.
        case snp = "biallelicSNP"
        /// Every locus is a microsatellite.
        case microsatellite
        /// The file has no loci.
        case none
        /// More than one marker type is present. Not expected in practice —
        /// a dataset is SNP-only or microsatellite-only — but recorded
        /// rather than silently picking one if it were ever to happen.
        case mixed
    }

    /// The project's name. Always present, written unconditionally at `create` time.
    public var projectName: String
    /// The species this project concerns, if given.
    public var species: String?
    /// Free-text description of what this project is focused on — a
    /// paragraph or two the user can write about the study's purpose.
    public var description: String?
    /// When this file was created.
    public var createdAt: Date
    /// `nil` if `.geneticData` was never written to this file.
    public var individualCount: Int?
    /// `nil` if `.geneticData` was never written to this file.
    public var locusCount: Int?
    /// `nil` if `.geneticData` was never written to this file.
    public var markerComposition: MarkerComposition?
    /// `nil` if `.geneticData` was never written to this file.
    public var hasParentage: Bool?
    /// `nil` if the file's `.graph` component wasn't created at all.
    public var hasGraph: Bool?
    /// `nil` if the file's `.results` component wasn't created at all.
    public var hasResults: Bool?
    /// `nil` if the file's `.log` component wasn't created at all.
    public var hasLog: Bool?
    /// `nil` if the file's `.matrices` component wasn't created at all.
    public var hasMatrices: Bool?

    /// Initializes a dataset summary.
    ///
    /// - Parameters:
    ///   - projectName: The project's name.
    ///   - species: The species this project concerns, if given.
    ///   - description: Free-text description of the project's focus.
    ///   - createdAt: When the file was created.
    ///   - individualCount: `nil` if `.geneticData` wasn't written.
    ///   - locusCount: `nil` if `.geneticData` wasn't written.
    ///   - markerComposition: `nil` if `.geneticData` wasn't written.
    ///   - hasParentage: `nil` if `.geneticData` wasn't written.
    ///   - hasGraph: `nil` if the `.graph` component wasn't created.
    ///   - hasResults: `nil` if the `.results` component wasn't created.
    ///   - hasLog: `nil` if the `.log` component wasn't created.
    ///   - hasMatrices: `nil` if the `.matrices` component wasn't created.
    public init(projectName: String, species: String?, description: String? = nil, createdAt: Date,
                individualCount: Int? = nil, locusCount: Int? = nil, markerComposition: MarkerComposition? = nil,
                hasParentage: Bool? = nil, hasGraph: Bool? = nil, hasResults: Bool? = nil, hasLog: Bool? = nil,
                hasMatrices: Bool? = nil) {
        self.projectName = projectName
        self.species = species
        self.description = description
        self.createdAt = createdAt
        self.individualCount = individualCount
        self.locusCount = locusCount
        self.markerComposition = markerComposition
        self.hasParentage = hasParentage
        self.hasGraph = hasGraph
        self.hasResults = hasResults
        self.hasLog = hasLog
        self.hasMatrices = hasMatrices
    }
}
