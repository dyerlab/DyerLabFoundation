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
//  A cheap, file-level classification of a persisted GenotypeMatrixStore
//  file's contents, read straight from the `meta` table (see
//  `GenotypeMatrixStore+Summary.swift`) with no genotype/graph/result
//  decoding. Intended for callers that need to classify a file — e.g. an
//  "Open Recent" list choosing an icon for parentage vs. non-parentage,
//  SNP vs. microsatellite — without paying for `readDataset()`.
//

import Foundation

/// A cheap, file-level summary of what a persisted `GenotypeMatrixStore`
/// file contains.
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

    public var projectName: String
    public var species: String?
    public var createdAt: Date
    public var individualCount: Int
    public var locusCount: Int
    public var markerComposition: MarkerComposition
    public var hasParentage: Bool
    public var hasGraph: Bool
    public var hasResults: Bool

    public init(projectName: String, species: String?, createdAt: Date, individualCount: Int, locusCount: Int,
                markerComposition: MarkerComposition, hasParentage: Bool, hasGraph: Bool, hasResults: Bool) {
        self.projectName = projectName
        self.species = species
        self.createdAt = createdAt
        self.individualCount = individualCount
        self.locusCount = locusCount
        self.markerComposition = markerComposition
        self.hasParentage = hasParentage
        self.hasGraph = hasGraph
        self.hasResults = hasResults
    }
}
