//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PlotForm+Stored.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

public extension PlotForm {

    /// The default number of bins when a stored histogram doesn't give one.
    static let defaultBins = 10

    /// The form's name in a stored figure.
    var storedName: String {
        switch self {
        case .histogram: "histogram"
        case .density: "density"
        case .bars: "bars"
        case .scatter: "scatter"
        }
    }

    /// The form's number of bins in a stored figure, if it has bins.
    var storedBins: Int? {
        if case .histogram(let bins) = self { return bins }
        return nil
    }

    /// Reads a form from a stored figure.
    ///
    /// - Parameters:
    ///   - storedName: The form's stored name.
    ///   - bins: The number of histogram bins, if given.
    /// - Returns: The form, or `nil` for a name this version doesn't know.
    init?(storedName: String, bins: Int?) {
        switch storedName {
        case "histogram": self = .histogram(bins: Swift.max(1, bins ?? Self.defaultBins))
        case "density": self = .density
        case "bars": self = .bars
        case "scatter": self = .scatter
        default: return nil
        }
    }
}
