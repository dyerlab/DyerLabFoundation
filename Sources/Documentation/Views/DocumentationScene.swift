//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationScene.swift
//  Documentation
//
//  The help window. An app adds it beside its document scenes and opens it
//  with `openWindow(id: DocumentationScene.windowID)`, as `DocumentationLink`
//  and `DocumentationCommands` do. On the Mac it is a single window, so
//  every help link turns the same window to its topic; on iPadOS it is a
//  scene of its own beside the app's. The platform files add the `Scene`
//  conformance.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// The window an app's help is browsed in.
public struct DocumentationScene {
    /// The window's id, for `openWindow(id:)`.
    public static let windowID = "documentation"

    /// The help the window shows.
    public let library: DocumentationLibrary

    /// Creates the help window.
    ///
    /// - Parameter library: The help it shows, shared with the app's help links.
    public init(library: DocumentationLibrary) {
        self.library = library
    }
}
