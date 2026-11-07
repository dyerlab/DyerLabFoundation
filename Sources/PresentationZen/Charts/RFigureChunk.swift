//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RFigureChunk.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Matrix

/// R code that redraws a figure from its values with ggplot2, to paste into an R chunk in a manuscript.
///
/// The figure's anchor and legend are `#|` options rather than chunk-header arguments, so the bare code keeps
/// them when pasted into an existing chunk; Quarto and knitr both read them.
///
/// ggplot's defaults would draw a different picture from ``DataPlot``'s: it extends histogram bins past the data
/// and closes them on the right, it stops a density at the data's range, and it sorts categories alphabetically.
/// The generated code overrides each of these so that the two plots agree.
public struct RFigureChunk: Equatable, Sendable {

    /// Six significant digits is more than a plot can show.
    private static let digits = 6

    /// The figure's anchor, also the base name of its exported file.
    public let anchor: String
    /// The bare R code, for an existing chunk, a script or the console.
    public let code: String
    /// The code in a fenced chunk, to paste anywhere in a Markdown document.
    public var fenced: String { Self.fenced(code) }

    // MARK: - Initialization

    /// Builds the chunk.
    ///
    /// - Parameters:
    ///   - title: The figure's title.
    ///   - legend: The figure's legend.
    ///   - table: The values, with roles bound as `form` requires.
    ///   - form: How the table is drawn.
    ///   - xLabel: The x-axis title.
    ///   - yLabel: The y-axis title.
    ///   - notes: Remarks to keep with the code as comments.
    /// - Returns: `nil` if the table doesn't bind the roles the form requires.
    public init?(title: String,
                 legend: String,
                 table: DataTable,
                 form: PlotForm,
                 xLabel: String,
                 yLabel: String,
                 notes: [String] = []) {
        guard let yColumn = table.column(for: .y) else { return nil }
        let y = RLiteral.name(yColumn)
        let values = table.column(yColumn)

        let mapping: String
        var layers: [String]
        switch form {
        case .histogram(let bins):
            mapping = y
            layers = [Self.histogramLayer(values, bins: bins)]
        case .density:
            mapping = y
            layers = Self.densityLayers(values)
        case .bars:
            guard let xColumn = table.column(for: .x) else { return nil }
            let x = RLiteral.name(xColumn)
            mapping = "\(table.kind(of: xColumn) == .category ? "fct_inorder( \(x) )" : x), \(y)"
            layers = ["geom_col()"]
            if table.rowCount > PlotForm.horizontalLabelLimit {
                layers.append("theme( axis.text.x = element_text( angle = 45, hjust = 1 ) )")
            }
        case .scatter:
            guard let xColumn = table.column(for: .x) else { return nil }
            mapping = "\(RLiteral.name(xColumn)), \(y)"
            layers = ["geom_point()"]
        }
        layers.append("labs( x = \(RLiteral.quoted(xLabel)), y = \(RLiteral.quoted(yLabel)) )")

        anchor = Self.anchor(for: title)
        // A manuscript wants the figure, not the listing of its values or tidyverse's startup banner.
        let caption = Self.caption(title: title, legend: legend)
        let options = ["#| label: \(anchor)",
                       "#| fig-cap: \(RLiteral.quoted(caption))",
                       "#| echo: false",
                       "#| message: false"] + notes.map { "# " + RLiteral.singleLine($0) }
        let plot = (["  ggplot( aes( \(mapping) ) )"] + layers.map { "  \($0)" }).joined(separator: " +\n")
        code = """
            \(options.joined(separator: "\n"))

            library( tidyverse )

            \(table.toR(significantDigits: Self.digits)) |>
            \(plot)

            """
    }

    /// Wraps R code in a fenced chunk, to paste anywhere in a Markdown document.
    ///
    /// - Parameter code: The code, ending in a newline.
    /// - Returns: The fenced chunk.
    public static func fenced(_ code: String) -> String {
        "```{r}\n\(code)```\n"
    }

    /// Makes a title into a URL- and file-safe anchor: `"He by latitude"` becomes `fig-he-by-latitude`.
    ///
    /// - Parameter title: The figure's title.
    /// - Returns: The anchor; `fig-plot` if the title has no usable characters.
    public static func anchor(for title: String) -> String {
        let folded = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "en"))
        let words = folded.split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }
        return "fig-" + (words.isEmpty ? "plot" : words.joined(separator: "-"))
    }

    // MARK: - Layers

    /// Builds a histogram layer with ``DataPlot``'s bins: equal widths across the data's range, each including its
    /// lower edge.
    ///
    /// - Parameters:
    ///   - values: The plotted values.
    ///   - bins: The number of bins.
    /// - Returns: The ggplot layer.
    private static func histogramLayer(_ values: [Double], bins: Int) -> String {
        guard let low = values.min(), let high = values.max(), low < high else {
            return "geom_histogram( bins = 1 )"
        }
        return "geom_histogram( breaks = seq( \(RLiteral.number(low, digits: digits)), "
            + "\(RLiteral.number(high, digits: digits)), length.out = \(bins + 1) ), closed = \"left\" )"
    }

    /// Builds the layers for a density curve over ``DataPlot``'s range, which runs past the data as `density()` does.
    ///
    /// - Parameter values: The plotted values.
    /// - Returns: The ggplot layers.
    private static func densityLayers(_ values: [Double]) -> [String] {
        let curve = KernelDensity(values, points: 2)
        guard let low = curve.first?.x, let high = curve.last?.x else { return ["geom_density()"] }
        return ["geom_density()",
                "xlim( \(RLiteral.number(low, digits: digits)), \(RLiteral.number(high, digits: digits)) )"]
    }

    // MARK: - Text

    private static func caption(title: String, legend: String) -> String {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let heading = title.hasSuffix(".") ? title : "\(title)."
        let legend = legend.trimmingCharacters(in: .whitespacesAndNewlines)
        return legend.isEmpty ? heading : "\(heading) \(legend)"
    }
}
