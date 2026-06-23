//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  PlotValue.swift
//
//  The typed value of a positional (x) encoding. A plottable position is
//  always exactly one of three kinds — quantitative, temporal, or
//  categorical — so the kind travels *with* the value instead of being
//  inferred from which field happens to be populated.
//

import Foundation

/// A single positional value that knows its own kind.
///
/// Charts switch on a `PlotValue` to choose the correct Swift Charts mark
/// argument (a `Double`, `Date`, or `String` plottable).
public enum PlotValue: Hashable, Sendable {
    /// A quantitative value (continuous axis).
    case number(Double)
    /// A temporal value (date axis).
    case date(Date)
    /// A categorical value (discrete axis).
    case category(String)
}

public extension PlotValue {

    /// The wrapped quantitative value, or `nil` for non-numeric kinds.
    var doubleValue: Double? {
        if case let .number(value) = self { return value }
        return nil
    }

    /// The wrapped temporal value, or `nil` for non-date kinds.
    var dateValue: Date? {
        if case let .date(value) = self { return value }
        return nil
    }

    /// The wrapped categorical value, or `nil` for non-categorical kinds.
    var stringValue: String? {
        if case let .category(value) = self { return value }
        return nil
    }
}
