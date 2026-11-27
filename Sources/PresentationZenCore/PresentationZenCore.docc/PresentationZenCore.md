# ``PresentationZenCore``

Charts, data tables, figures and their exports, built only on Swift Charts and TabularData.

## Overview

`PresentationZenCore` is what an app needs to show its data without the C++ `Matrix` library or `Graph`: it
depends only on `DyerlabCore`, which it re-exports. `PresentationZen` re-exports this target in turn and adds what
needs `Matrix` or `Graph`: `DataPlot`, the `Matrix` and `Vector` views, the analysis charts and the `StoredFigure`
model. Code that imports `PresentationZen` sees everything here without a second import.

### Data tables

- ``DataTable`` — a role-mapped, column-typed table on a `TabularData.DataFrame` (``DataColumnRole``,
  ``ColumnKind``, ``PlotValue``). `csvText` and `tabSeparatedText` give it as text for a file or a spreadsheet, and
  `markdownText(caption:anchor:decimals:)` as a Markdown table.
- ``PlotRow`` — one row prepared for charting, `Sendable`, for crossing actors where a `DataTable` can't.
- ``DataTableView`` — a SwiftUI view over a `DataTable`.
- ``TabularOutputView`` — a results table, such as an AMOVA, in publication style, with ``TableExportMenu`` and
  ``TableExportOutput`` to copy or export it.
- ``CSVDocument`` — a `FileDocument` for exporting CSV text.

### Charts

- ``BarPlot``, ``BarListPlot``, ``GroupedBarPlot``, ``PiePlot`` — categories: vertical bars, a ranked list of
  labelled horizontal bars, side-by-side bars per series, and a pie.
- ``ScatterPlot``, ``TimeSeriesPlot``, ``DistributionPlot``, ``NumberLine`` — values against each other, over time,
  as a distribution, and along a line.
- ``SequencePlot`` — values in order (game 1, 2, 3, ...) with a trend line, ``SequenceBand`` shading for the stretches
  that belong together, and ``SequenceMarker`` rules for what happened between two positions.
- ``PlotForm`` — the standard ways a table is drawn (`histogram`, `density`, `bars`, `scatter`, ...), with their
  stored names.
- ``PlotStyle`` — `figure` (large axis titles, a minimum height) or `compact` (sized by its container, for a chart
  inside an app screen).

### Calendars

- ``ActivityGrid`` — a contribution-style grid of recent days, filled on days with activity.
- ``DailyPresencePlot`` and ``DailyPresenceSeries`` — a month of days against a set of series, marking the days each
  has data.
- ``MonthSelectorView`` — a month title with previous and next buttons that step a bound date.

### Figures and exports

- ``FigureColumn`` / ``FigureGenerator`` — the columns of a figure stored in a project file and the program that can
  recompute it; `PresentationZen`'s `StoredFigure` holds them.
- ``ResultRecord`` — what a figure records about the analysis that made it (log text, analyst notes, data version).
- ``PlotExportMenu`` / ``PlotExportOutput`` / ``PlotExportFile`` / ``PlotExportError`` / ``PlotImageFormat`` — the
  copy and export menu and what it produces. Clipboard outputs are handled here; saving a file is left to the app.
- `View.pngData(_:)` — any view rendered to a PNG through ImageIO, with no platform code.
- ``FigureTextEditor`` — editing a figure's title and legend.
- ``StoredMatrixInfo`` — a matrix kept in a project file, described without its values.

### Platform-neutral types

- ``DLColor``, ``DLImage``, ``DLPasteboard`` — one name for what UIKit and AppKit each provide.
- ``MapBaseStyle`` / ``MapStylePicker`` / ``MapViewport`` — a map's base layer, the control that picks it, and its
  visible area captured from a camera change.
- ``MappableNode`` — anything with a coordinate that can be placed on a map.
- ``ConvexHull`` — the convex hull of a set of points, for area coverage.
- ``WrappingHStack`` — a row of views that wraps onto new lines.

### Models and media

- ``Media`` / `MediaPicker` — a SwiftData media model (its `@Model` macro needs Xcode's build system) and, on iOS and visionOS, a picker
  for it.
- ``AnalysisResult`` / ``ResultImage`` — a stored analysis result and its rendered image.
- ``PointCluster`` — a cluster of points from k-means clustering, as `DLImage` uses to find dominant colors.
