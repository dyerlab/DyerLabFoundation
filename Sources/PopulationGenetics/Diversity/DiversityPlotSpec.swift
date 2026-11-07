//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityPlotSpec.swift
//  PopulationGenetics
//
//  What a diversity plot shows, without any of its numbers: a saved plot stores
//  this and recomputes from the current genotypes, so it follows data edits. The
//  choices are stored as JSON in the project file, so raw values must not change.
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The parameters of a diversity plot.
///
/// The predictor sets the plot's form: none gives a distribution, a categorical
/// one a bar plot, and a continuous one a scatter plot.
public struct DiversityPlotSpec: Codable, Hashable, Sendable {

    /// What the response is plotted against.
    public enum Predictor: String, CaseIterable, Identifiable, Codable, Sendable {
        /// Nothing: the response's distribution.
        case none
        /// Each locus.
        case locus
        /// Each population.
        case population
        /// Each maternal family.
        case family
        /// The group's mean latitude.
        case latitude
        /// The group's mean longitude.
        case longitude
        /// The number of individuals in the group.
        case sampleSize

        /// The predictor itself.
        public var id: Self { self }

        /// The predictor's name in menus.
        public var title: String {
            switch self {
            case .none: "None (distribution)"
            case .locus: "Locus"
            case .population: "Population"
            case .family: "Family"
            case .latitude: "Latitude"
            case .longitude: "Longitude"
            case .sampleSize: "Sample size"
            }
        }

        /// Whether the predictor is a continuous measure, drawn as a scatter plot.
        public var isContinuous: Bool { self == .latitude || self == .longitude || self == .sampleSize }

        /// The name of the column holding the predictor's values, valid in R as well as a spreadsheet.
        public var columnName: String { self == .sampleSize ? "sample_size" : rawValue }
    }

    /// What one value in a distribution stands for.
    public enum Unit: String, CaseIterable, Identifiable, Codable, Sendable {
        /// One value per locus.
        case locus
        /// One value per population.
        case population
        /// One value per maternal family.
        case family
        /// One value per locus in each population.
        case locusWithinPopulation
        /// One value per locus in each maternal family.
        case locusWithinFamily

        /// The unit itself.
        public var id: Self { self }

        /// The unit's name in menus.
        public var title: String {
            switch self {
            case .locus: "Loci"
            case .population: "Populations"
            case .family: "Families"
            case .locusWithinPopulation: "Loci within populations"
            case .locusWithinFamily: "Loci within families"
            }
        }
    }

    /// Which individuals a per-locus value is computed from.
    public enum Sample: Codable, Hashable, Sendable {
        /// All adults counted together.
        case pooled
        /// The value within each group, averaged across groups.
        case meanWithinGroups
        /// One population or family.
        case group(name: String)
    }

    /// How a distribution is drawn.
    public enum DistributionStyle: String, CaseIterable, Identifiable, Codable, Sendable {
        /// Counts in equal-width bins.
        case histogram
        /// A Gaussian kernel density curve.
        case density

        /// The style itself.
        public var id: Self { self }

        /// The style's name in the picker.
        public var title: String {
            switch self {
            case .histogram: "Histogram"
            case .density: "Density"
            }
        }
    }

    /// The form a plot takes.
    public enum Form: Equatable, Sendable {
        /// A histogram or density curve of one variable.
        case distribution
        /// A bar for each category.
        case bars
        /// A point for each group.
        case scatter
    }

    /// The default number of histogram bins.
    public static let defaultBins = 10

    /// The statistic plotted.
    public var response = DiversityType.He
    /// What the statistic is plotted against.
    public var predictor = Predictor.none
    /// What one value stands for, when there is no predictor.
    public var unit = Unit.locus
    /// How a distribution is drawn.
    public var style = DistributionStyle.histogram
    /// The number of histogram bins.
    public var bins = DiversityPlotSpec.defaultBins
    /// The one locus a per-group value comes from, or `nil` to average across loci.
    public var locus: String?
    /// The individuals a per-locus value comes from.
    public var sample = Sample.pooled

    /// Creates a plot's parameters.
    ///
    /// - Parameters:
    ///   - response: The statistic plotted.
    ///   - predictor: What the statistic is plotted against.
    ///   - unit: What one value stands for, when there is no predictor.
    ///   - style: How a distribution is drawn.
    ///   - bins: The number of histogram bins.
    ///   - locus: The one locus a per-group value comes from, or `nil` to average across loci.
    ///   - sample: The individuals a per-locus value comes from.
    public init(response: DiversityType = .He,
                predictor: Predictor = .none,
                unit: Unit = .locus,
                style: DistributionStyle = .histogram,
                bins: Int = DiversityPlotSpec.defaultBins,
                locus: String? = nil,
                sample: Sample = .pooled) {
        self.response = response
        self.predictor = predictor
        self.unit = unit
        self.style = style
        self.bins = bins
        self.locus = locus
        self.sample = sample
    }

    /// The form this plot takes.
    public var form: Form {
        if predictor == .none { return .distribution }
        return predictor.isContinuous ? .scatter : .bars
    }

    /// The unit each value stands for, whether set directly or implied by the predictor.
    ///
    /// Continuous predictors describe groups, so `primaryGroupUnit` says which kind of group they
    /// use.
    ///
    /// - Parameter primaryGroupUnit: The dataset's main grouping.
    /// - Returns: The effective unit.
    public func effectiveUnit(primaryGroupUnit: Unit) -> Unit {
        switch predictor {
        case .none: unit
        case .locus: .locus
        case .population: .population
        case .family: .family
        case .latitude, .longitude, .sampleSize: primaryGroupUnit
        }
    }

    /// Whether the plot has one value per locus, so `sample` applies.
    public var usesSample: Bool { predictor == .locus || (predictor == .none && unit == .locus) }

    /// Whether the plot has one value per group, so `locus` applies.
    public var usesLocus: Bool {
        switch predictor {
        case .none: unit == .population || unit == .family
        case .locus: false
        default: true
        }
    }

    /// This spec with every parameter the plot doesn't use reset, so that two
    /// specs drawing the same plot compare equal.
    public var normalized: DiversityPlotSpec {
        var spec = self
        if predictor != .none { spec.unit = .locus }
        if form != .distribution { spec.style = .histogram }
        if form != .distribution || style != .histogram { spec.bins = Self.defaultBins }
        if !usesLocus { spec.locus = nil }
        if !usesSample { spec.sample = .pooled }
        return spec
    }
}
