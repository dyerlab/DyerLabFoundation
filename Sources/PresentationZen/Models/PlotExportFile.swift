//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PlotExportFile.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import UniformTypeIdentifiers

/// An exported plot, ready for the app to save wherever its platform's file dialog says.
public struct PlotExportFile: Equatable, Sendable {
    /// The file's contents.
    public let data: Data
    /// The file's type.
    public let contentType: UTType
    /// A base name for the file, without an extension.
    public let suggestedName: String

    /// Creates an exported file.
    ///
    /// - Parameters:
    ///   - data: The file's contents.
    ///   - contentType: The file's type.
    ///   - suggestedName: A base name for the file, without an extension.
    public init(data: Data, contentType: UTType, suggestedName: String) {
        self.data = data
        self.contentType = contentType
        self.suggestedName = suggestedName
    }
}
