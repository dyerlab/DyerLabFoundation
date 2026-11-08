//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationCommands.swift
//  Documentation
//
//  The Help menu's item for the app's help, in place of the system's own,
//  which looks for a Help Book the app doesn't have. ⌘? opens the help at
//  its first page.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// The Help menu item that opens the help window.
public struct DocumentationCommands: Commands {
    /// The help it opens.
    public let library: DocumentationLibrary

    @Environment(\.openWindow) private var openWindow

    /// Creates the Help menu item.
    ///
    /// - Parameter library: The help it opens.
    public init(library: DocumentationLibrary) {
        self.library = library
    }

    /// The Help menu item.
    public var body: some Commands {
        CommandGroup(replacing: .help) {
            Button(library.index.title) {
                if let home = library.index.home { library.show(home) }
                openWindow(id: DocumentationScene.windowID)
            }
            .keyboardShortcut("?", modifiers: .command)
        }
    }
}
