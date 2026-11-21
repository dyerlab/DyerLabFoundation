//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FigureTextEditor.swift
//  PresentationZen
//
//  A sheet rather than editing in a list, so that one change to the text is one undo step in the
//  document rather than one per keystroke.
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A sheet for a figure's title and legend.
public struct FigureTextEditor: View {
    /// The sheet's heading.
    public let heading: String
    /// Called with the trimmed title and legend when the user confirms.
    public let commit: (_ title: String, _ legend: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var legend: String

    // MARK: - Initialization

    /// Creates the sheet.
    ///
    /// - Parameters:
    ///   - heading: The sheet's heading.
    ///   - title: The starting title.
    ///   - legend: The starting legend.
    ///   - commit: Called with the trimmed title and legend when the user confirms.
    public init(heading: String,
                title: String,
                legend: String,
                commit: @escaping (_ title: String, _ legend: String) -> Void) {
        self.heading = heading
        self.commit = commit
        _title = State(initialValue: title)
        _legend = State(initialValue: legend)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heading)
                .font(.headline)
            TextField("Title", text: $title)
            Text("Figure Legend")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextEditor(text: $legend)
                .font(.body)
                .frame(minHeight: 100)
                .border(.separator)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    commit(trimmedTitle, legend.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedTitle.isEmpty)
            }
        }
        .padding()
        #if os(macOS)
        .frame(width: 440)
        #endif
    }
}

// MARK: - Previews

#Preview {
    FigureTextEditor(heading: "Save Plot",
                     title: "He by latitude",
                     legend: "Expected heterozygosity (He) for each population, averaged across loci.") { _, _ in }
}
