//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FigureRow.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A figure's picture, title and legend, for a list.
///
/// A figure stored without images, as R can write them, is drawn from its values.
public struct FigureRow: View {
    /// The figure to show.
    public let figure: StoredFigure
    /// The program whose figures need no note of where they came from.
    public let localSource: String?

    @State private var drawn: Data?

    /// Creates a row.
    ///
    /// - Parameters:
    ///   - figure: The figure to show.
    ///   - localSource: The program whose figures need no note of where they came from.
    public init(figure: StoredFigure, localSource: String? = nil) {
        self.figure = figure
        self.localSource = localSource
    }

    private var foreignSource: String? {
        figure.source.isEmpty || figure.source == localSource ? nil : figure.source
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            picture
            Text(figure.title)
                .font(.headline)
                .lineLimit(2)
            if !figure.legend.isEmpty {
                Text(figure.legend)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if let foreignSource {
                Label("From \(foreignSource)", systemImage: "arrow.down.doc")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        // The whole row answers a right-click, not only its text and image.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .task(id: figure) {
            drawn = figure.previewImage == nil && !figure.isTable ? figure.plot?.pngData(.thumbnail) : nil
        }
    }

    @ViewBuilder
    private var picture: some View {
        if figure.isTable, let table = figure.table {
            TabularOutputView(table, decimals: 3, size: .compact)
        } else if let data = figure.previewImage?.data ?? drawn, let image = DLImage(data: data) {
            Image(dlImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(.rect(cornerRadius: 4))
        }
    }
}

// MARK: - Previews

#Preview("Drawn from values") {
    FigureRow(figure: StoredFigure(title: "He by population",
                                   legend: "Written by gstudio.",
                                   source: "gstudio",
                                   formName: "bars",
                                   columns: [FigureColumn(name: "population", role: .x, values: .text(["A", "B"])),
                                             FigureColumn(name: "He", role: .y, values: .numbers([0.4, 0.5]))]),
              localSource: "GeneticStudio")
        .frame(width: 260)
        .padding()
}
