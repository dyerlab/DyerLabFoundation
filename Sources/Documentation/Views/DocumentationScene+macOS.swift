//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationScene+macOS.swift
//  Documentation
//
//  The help window on the Mac: one window, reopened where it was left.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

#if os(macOS)
import SwiftUI

extension DocumentationScene: Scene {
    /// The help window.
    public var body: some Scene {
        Window(library.index.title, id: Self.windowID) {
            DocumentationBrowser(library: library)
                .environment(library)
        }
        .defaultSize(width: 1040, height: 720)
        .commandsRemoved()
    }
}
#endif
