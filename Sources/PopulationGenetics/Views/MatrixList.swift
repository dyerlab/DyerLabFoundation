//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MatrixList.swift
//  PopulationGenetics
//
//  The matrices stored in a project file, as the Distance page's sidebar
//  lists them below its saved analyses: each with what it is, and a menu to
//  export, copy or delete it. GeneticStudio computes its own matrices when
//  needed, so these come from elsewhere, such as R, and are shown as stored.
//  Matrices are named uniquely (a file read back keeps one per name), so the
//  name is the selection.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// The stored matrices, with a menu for each.
public struct MatrixList: View {

    /// What can be done to a stored matrix.
    public enum Action: Sendable {
        /// Save it as a CSV file.
        case exportCSV
        /// Copy it to the clipboard as CSV.
        case copyCSV
        /// Remove it from the project.
        case delete
    }

    /// The matrices.
    public let matrices: [MatrixAttachment]
    /// The selected matrix's name.
    @Binding public var selection: String?
    /// Carries out an action on a matrix.
    public let perform: (Action, MatrixAttachment) -> Void

    /// Creates the list.
    ///
    /// - Parameters:
    ///   - matrices: The matrices.
    ///   - selection: The selected matrix's name.
    ///   - perform: Carries out an action on a matrix.
    public init(matrices: [MatrixAttachment], selection: Binding<String?>,
                perform: @escaping (Action, MatrixAttachment) -> Void) {
        self.matrices = matrices
        _selection = selection
        self.perform = perform
    }

    // MARK: - Body

    /// The list.
    public var body: some View {
        List(matrices, id: \.name, selection: $selection) { matrix in
            row(matrix)
                .contextMenu { menu(for: matrix) }
        }
    }

    private func row(_ matrix: MatrixAttachment) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(matrix.name, systemImage: "square.grid.3x3")
                .font(.body)
            if let description = matrix.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func menu(for matrix: MatrixAttachment) -> some View {
        Button("Export CSV…", systemImage: "square.and.arrow.up") { perform(.exportCSV, matrix) }
        Button("Copy as CSV", systemImage: "doc.on.clipboard") { perform(.copyCSV, matrix) }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { perform(.delete, matrix) }
    }
}

// MARK: - Previews

#Preview("Matrices") {
    @Previewable @State var selection: String?
    MatrixList(matrices: [MatrixAttachment(name: "Fst from R", description: "Pairwise Fst among populations",
                                           data: Data()),
                          MatrixAttachment(name: "Resistance distances", data: Data())],
               selection: $selection, perform: { _, _ in })
        .frame(width: 280, height: 420)
}
