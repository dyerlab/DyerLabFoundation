//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PlotExportError.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Why a plot couldn't be exported.
public enum PlotExportError: LocalizedError, Equatable {
    /// The plot can't be drawn from the current data, for the given reason.
    case plotUnavailable(String)
    /// The plot couldn't be rendered to an image.
    case renderingFailed

    /// A description for an alert.
    public var errorDescription: String? {
        switch self {
        case .plotUnavailable(let reason): "This plot can't be exported. \(reason)"
        case .renderingFailed: "The plot could not be rendered to an image."
        }
    }
}
