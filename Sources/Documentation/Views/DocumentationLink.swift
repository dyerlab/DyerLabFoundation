//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationLink.swift
//  Documentation
//
//  The round (?) button that opens the help window at a topic. It reads the
//  app's `DocumentationLibrary` from the environment, so it can sit inside
//  any view, including one from a package that knows nothing of the app's
//  help, and it draws nothing when the environment has no library or the
//  library has no such topic, rather than a button that goes nowhere. The
//  platform files draw it: the system `HelpLink` on the Mac, and a
//  question-mark button on iPadOS, which has no `HelpLink`.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A help button that opens the help window at a topic.
@MainActor
public struct DocumentationLink {
    /// The topic's entry id.
    public let topic: DocumentationEntry.ID

    @Environment(DocumentationLibrary.self) var library: DocumentationLibrary?
    @Environment(\.openWindow) var openWindow

    /// Creates a help button.
    ///
    /// - Parameter topic: The id of the help entry it opens.
    public init(_ topic: DocumentationEntry.ID) {
        self.topic = topic
    }

    /// The topic's entry, when the environment's help has it.
    var entry: DocumentationEntry? {
        library?.index.entry(topic)
    }

    /// Opens the help window at the topic.
    func open() {
        library?.show(topic)
        openWindow(id: DocumentationScene.windowID)
    }
}

// MARK: - Previews

#Preview("In a toolbar row") {
    HStack {
        Text("Nonrandom Mating")
        DocumentationLink("sample.inbreeding")
    }
    .padding()
    .environment(DocumentationLibrary.sample)
}
