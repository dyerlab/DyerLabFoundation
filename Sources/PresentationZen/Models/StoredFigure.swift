//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StoredFigure.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A figure kept in a project file, made by any program that can write the file.
///
/// A figure can be drawn in up to three ways, and a program uses the best it can:
/// - A ``generator`` it knows recomputes the figure from the project's current data, using ``spec``.
/// - A ``formName`` it knows redraws the stored ``columns`` natively.
/// - Otherwise the stored ``images`` are shown as they are.
///
/// Everything is kept across a save, including what this version can't interpret. See the PopulationGenetics
/// article on figure storage for the file format, which R reads and writes too.
public struct StoredFigure: Identifiable, Equatable, Sendable {

    /// The name of the small image a figure list shows.
    public static let thumbnailImageName = "thumbnail"
    /// The name of the full-resolution image, which is what an export prefers.
    public static let figureImageName = "figure"

    /// The figure's identity.
    public var id: UUID
    /// The figure's title.
    public var title: String
    /// The figure's legend.
    public var legend: String
    /// The program that made the figure, such as `GeneticStudio` or `gstudio`.
    public var source: String
    /// How the columns are drawn: a ``PlotForm`` name, or `nil` for a figure that is only images.
    public var formName: String?
    /// The number of histogram bins, if the form has bins.
    public var bins: Int?
    /// The x-axis title.
    public var xLabel: String?
    /// The y-axis title.
    public var yLabel: String?
    /// The code that can recompute the figure, if any.
    public var generator: FigureGenerator?
    /// The generator's parameters, as JSON whose meaning belongs to the generator.
    public var spec: String?
    /// R code that redraws the figure.
    public var rCode: String?
    /// When the figure was made.
    public var createdAt: Date
    /// The values plotted, as of the last save.
    public var columns: [FigureColumn]
    /// Pictures of the figure, named by ``thumbnailImageName`` and ``figureImageName``.
    public var images: [ResultImage]

    /// Creates a figure.
    ///
    /// - Parameters:
    ///   - id: The figure's identity.
    ///   - title: The figure's title.
    ///   - legend: The figure's legend.
    ///   - source: The program making the figure.
    ///   - formName: How the columns are drawn, or `nil` for a figure that is only images.
    ///   - bins: The number of histogram bins, if the form has bins.
    ///   - xLabel: The x-axis title.
    ///   - yLabel: The y-axis title.
    ///   - generator: The code that can recompute the figure, if any.
    ///   - spec: The generator's parameters, as JSON.
    ///   - rCode: R code that redraws the figure.
    ///   - createdAt: When the figure was made.
    ///   - columns: The values plotted.
    ///   - images: Pictures of the figure.
    public init(id: UUID = UUID(),
                title: String,
                legend: String = "",
                source: String = "",
                formName: String? = nil,
                bins: Int? = nil,
                xLabel: String? = nil,
                yLabel: String? = nil,
                generator: FigureGenerator? = nil,
                spec: String? = nil,
                rCode: String? = nil,
                createdAt: Date = Date(),
                columns: [FigureColumn] = [],
                images: [ResultImage] = []) {
        self.id = id
        self.title = title
        self.legend = legend
        self.source = source
        self.formName = formName
        self.bins = bins
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.generator = generator
        self.spec = spec
        self.rCode = rCode
        self.createdAt = createdAt
        self.columns = columns
        self.images = images
    }

    /// The small image a figure list shows: the thumbnail, or else the full image.
    public var previewImage: ResultImage? {
        image(named: Self.thumbnailImageName) ?? image(named: Self.figureImageName)
    }

    /// Finds one of the figure's images.
    ///
    /// - Parameter name: The image's name.
    /// - Returns: The image, or `nil` if the figure has none by that name.
    public func image(named name: String) -> ResultImage? {
        images.first { $0.name == name }
    }

    /// Replaces or adds an image, or removes it.
    ///
    /// - Parameters:
    ///   - data: The image's bytes, or `nil` to remove it.
    ///   - name: The image's name.
    ///   - width: Its pixel width, if known.
    ///   - height: Its pixel height, if known.
    public mutating func setImage(_ data: Data?, named name: String, width: Int? = nil, height: Int? = nil) {
        images.removeAll { $0.name == name }
        if let data { images.append(ResultImage(name: name, width: width, height: height, data: data)) }
    }

    /// The form the columns are drawn in, or `nil` if there is none or this version doesn't know it.
    public var form: PlotForm? {
        formName.flatMap { PlotForm(storedName: $0, bins: bins) }
    }

    /// The stored values as a table, or `nil` if there are none or their columns can't form one.
    public var table: DataTable? {
        columns.isEmpty ? nil : DataTable(figureColumns: columns)
    }

    /// Stores a table and how it is drawn, with the code that redraws them, replacing any earlier values.
    ///
    /// - Parameters:
    ///   - table: The values, with roles bound as `form` requires.
    ///   - form: How the table is drawn.
    ///   - xLabel: The x-axis title.
    ///   - yLabel: The y-axis title.
    ///   - notes: Remarks to keep with the code as comments.
    ///   - extraLayers: ggplot2 layers the code adds after the form's own, such as a fitted line.
    public mutating func store(_ table: DataTable,
                               form: PlotForm,
                               xLabel: String,
                               yLabel: String,
                               notes: [String] = [],
                               extraLayers: [String] = []) {
        columns = table.figureColumns
        formName = form.storedName
        bins = form.storedBins
        self.xLabel = xLabel
        self.yLabel = yLabel
        rCode = RFigureChunk(title: title, legend: legend, table: table, form: form, xLabel: xLabel, yLabel: yLabel,
                             notes: notes, extraLayers: extraLayers)?.code
    }
}
