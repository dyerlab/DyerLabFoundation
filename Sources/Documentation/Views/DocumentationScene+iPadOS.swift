//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationScene+iPadOS.swift
//  Documentation
//
//  The help window on iPadOS (and visionOS): a scene of its own, which the
//  system may open beside the app's windows.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

#if os(iOS) || os(visionOS)
import SwiftUI

extension DocumentationScene: Scene {
    /// The help window.
    public var body: some Scene {
        WindowGroup(library.index.title, id: Self.windowID) {
            DocumentationBrowser(library: library)
                .environment(library)
        }
    }
}
#endif
