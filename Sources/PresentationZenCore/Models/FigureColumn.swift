//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FigureColumn.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// One column of the values a ``StoredFigure`` plots.
public struct FigureColumn: Equatable, Sendable {

    /// A column's values; `nil` is a missing value.
    public enum Values: Equatable, Sendable {
        /// Measurements.
        case numbers([Double?])
        /// Names.
        case text([String?])
        /// Times.
        case dates([Date?])

        /// The number of values.
        public var count: Int {
            switch self {
            case .numbers(let values): values.count
            case .text(let values): values.count
            case .dates(let values): values.count
            }
        }
    }

    /// The column's name.
    public var name: String
    /// The role the column plays in the plot, if any.
    public var role: DataColumnRole?
    /// The column's values.
    public var values: Values

    /// Creates a column.
    ///
    /// - Parameters:
    ///   - name: The column's name.
    ///   - role: The role the column plays in the plot, if any.
    ///   - values: The column's values.
    public init(name: String, role: DataColumnRole? = nil, values: Values) {
        self.name = name
        self.role = role
        self.values = values
    }
}
