//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  IBDSpec+Axis.swift
//  PopulationGenetics
//
//  A hypothesized axis, gstudio's `genetic_isolation(axis = )`: a position for
//  each unit, such as latitude or distance along a river. Separation along it is
//  |aⱼ − aᵢ|, and for directional isolation by graph distance (dcGD) the ordered
//  pair (i, j) runs forward when aⱼ > aᵢ. Latitude and longitude are each unit's
//  mean over its adults with coordinates, as gstudio averages an axis column
//  within strata. The raw values and keys are part of the file format.
//
//  Created by Rodney Dyer on 2026.11.21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

public extension IBDSpec {

    /// A position for each unit along a hypothesized axis.
    struct Axis: Codable, Hashable, Sendable {

        /// Where the positions come from.
        public enum Source: String, Codable, CaseIterable, Identifiable, Sendable {
            /// Each unit's mean latitude, so forward runs north.
            case latitude
            /// Each unit's mean longitude, so forward runs east.
            case longitude
            /// Positions given with the spec, such as river kilometres, by unit name.
            case positions

            /// The source itself.
            public var id: Self { self }
        }

        /// Where the positions come from.
        public var source: Source
        /// The axis's name for ``Source/positions``, such as "River km"; `nil` names it "Axis".
        public var name: String?
        /// Each unit's position for ``Source/positions``, by unit name; units without one are left out.
        public var positions: [String: Double]?

        /// Creates an axis.
        ///
        /// - Parameters:
        ///   - source: Where the positions come from.
        ///   - name: The axis's name, for given positions.
        ///   - positions: The positions by unit name, for ``Source/positions``.
        public init(source: Source, name: String? = nil, positions: [String: Double]? = nil) {
            self.source = source
            self.name = name
            self.positions = positions
        }

        /// The axis's name, such as "Latitude" or "River km".
        public var title: String {
            switch source {
            case .latitude: "Latitude"
            case .longitude: "Longitude"
            case .positions: name ?? "Axis"
            }
        }

        /// The separation's axis title, such as "Latitude difference (°)".
        public var separationLabel: String {
            switch source {
            case .latitude, .longitude: "\(title) difference (°)"
            case .positions: "\(title) difference"
            }
        }

        /// The separation as prose for Methods text, such as "the difference in latitude (°)".
        public var separationPhrase: String {
            switch source {
            case .latitude, .longitude: "the difference in \(title.lowercased()) (°)"
            case .positions: "the difference in \(title)"
            }
        }

        /// The separation's short name in a formula, such as `Δlat`.
        public var symbol: String {
            switch source {
            case .latitude: "Δlat"
            case .longitude: "Δlon"
            case .positions: "Δ\(name ?? "axis")"
            }
        }

        /// The separation's column name in a saved figure: `latitude_difference`, `longitude_difference` or
        /// `axis_difference`.
        public var columnName: String {
            switch source {
            case .latitude: "latitude_difference"
            case .longitude: "longitude_difference"
            case .positions: "axis_difference"
            }
        }

        /// Which way forward runs, for Methods text, such as "northward".
        public var forwardPhrase: String {
            switch source {
            case .latitude: "northward"
            case .longitude: "eastward"
            case .positions: "toward larger \(title)"
            }
        }
    }
}
