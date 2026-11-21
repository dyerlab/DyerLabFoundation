//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FigureGenerator.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The code that can recompute a ``StoredFigure`` from a project's current data.
///
/// This is an open tag, so a module can add its own with a `static let` in an extension. A figure whose generator
/// a program doesn't know still draws from its stored values, and is kept when the file is saved.
public struct FigureGenerator: RawRepresentable, Hashable, Sendable {
    /// The tag as stored in the file.
    public let rawValue: String

    /// Creates a generator tag.
    ///
    /// - Parameter rawValue: The tag as stored in the file.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
