//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StoredFigureView.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// Shows a figure as it is stored: redrawn from its values when possible, otherwise its image.
public struct StoredFigureView: View {
    /// The figure to show.
    public let figure: StoredFigure

    /// Creates the view.
    ///
    /// - Parameter figure: The figure to show.
    public init(figure: StoredFigure) {
        self.figure = figure
    }

    private var image: DLImage? {
        (figure.image(named: StoredFigure.figureImageName) ?? figure.previewImage ?? figure.images.first)
            .flatMap { DLImage(data: $0.data) }
    }

    public var body: some View {
        if figure.isTable, let table = figure.table {
            TabularOutputView(table, title: figure.title, caption: figure.legend)
        } else if let image = figure.image(named: StoredFigure.figureImageName).flatMap({ DLImage(data: $0.data) }) {
            picture(image)
        } else if let plot = figure.plot {
            plot
        } else if let image {
            picture(image)
        } else {
            ContentUnavailableView("Can't Show This Figure", systemImage: "questionmark.square",
                                   description: Text("It has no picture, and this version can't draw its values."))
        }
    }

    private func picture(_ image: DLImage) -> some View {
        Image(dlImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

// MARK: - Previews

#Preview("From values") {
    StoredFigureView(figure: StoredFigure(title: "He",
                                          formName: "bars",
                                          xLabel: "Population",
                                          yLabel: "He",
                                          columns: [FigureColumn(name: "p", role: .x, values: .text(["A", "B"])),
                                                    FigureColumn(name: "He", role: .y, values: .numbers([0.4, 0.5]))]))
        .frame(width: 500, height: 350)
        .padding()
}

#Preview("Nothing to show") {
    StoredFigureView(figure: StoredFigure(title: "Future", formName: "ridgeline"))
        .frame(width: 500, height: 350)
}
