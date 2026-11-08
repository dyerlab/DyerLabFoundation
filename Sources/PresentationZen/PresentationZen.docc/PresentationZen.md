# ``PresentationZen``

The SwiftUI presentation layer for `Matrix` — charts, statistical analyses, data tables, and views.

## Overview

`PresentationZen` depends on both `Matrix` and `Graph`. It is the UI layer for `Matrix`/`Vector` values and for
data communication (charts, tables, analyses) generally. `Graph` is the one exception: it owns its own SwiftUI
views (`GraphLayoutView`, `MapView`) alongside its model and layout-engine code, so it has no UI dependency on
this target.

### Data tables

- ``DataTable`` — a generic, column-typed data table (``DataColumnRole``, ``ColumnKind``, ``PlotValue``) with CSV import/export and conversions from a `Matrix`, `NullDistributionResult`, or pairwise matrix.
- ``DataTableView`` — a SwiftUI view over a `DataTable`.
- ``TabularOutputView`` — a results table, such as an AMOVA, in publication style. ``RTableChunk``, `markdownText(caption:anchor:decimals:)` and `exportTable(_:title:legend:rCode:notes:pasteboard:)` copy or export it as an R chunk, Markdown or CSV (``TableExportOutput``, ``TableExportMenu``). A ``StoredFigure`` of form `table` holds one.
- ``PlotRow`` — a single row prepared for charting.

### Charts

- ``BarPlot``, ``BoxPlot``, ``DistributionPlot``, ``Histogram``, ``NumberLine``, ``PiePlot``, ``ScatterPlot``, ``ScatterPlotWithTrendline``, ``TemporalScatterPlot``, ``TimeSeriesPlot`` — chart views, all built on `DataTable` / `PlotRow`.
- ``PairwiseScatterPlot`` — draws a `Matrix` `PairwiseScatter` (the isolation-by-distance family of outcomes): one colour per series, fitted lines, and a hover/tap tooltip naming each pair.
- `AnalysisReport.logEntries` — an analysis report (`Matrix`) as ``LogEntry`` values in manuscript order: the Methods passage (`.methods`), the notes, then the Results passage (`.results`), all tagged with the analysis's tag.

### Plots and their exports

- ``DataPlot`` — a `DataTable` drawn in a standard ``PlotForm``. Other modules build the table and choose the form; the drawing and every export come from here.
- `DataTable.toR()` — the table as a tibble. `DataTable.csvText` and `DataTable.tabSeparatedText` give it as text for a file or a spreadsheet.
- ``RFigureChunk`` — ggplot2 code that redraws a plot, with its anchor and caption, to paste into an R chunk.
- `View.pngData(_:)` / ``PlotImageFormat`` — any view, usually a chart, rendered to a PNG.
- ``PlotExportMenu`` / ``PlotExportOutput`` / ``PlotExportFile`` / ``PlotExportError`` — the copy and export menu, and what it produces. Clipboard outputs are handled here; saving a file is left to the app, since file dialogs differ by platform.

### Stored figures

- ``StoredFigure`` / ``FigureColumn`` / ``FigureGenerator`` — a figure kept in a project file by any program: values, how they're drawn, R code and pictures. It exports like a `DataPlot`, from whatever it holds. PopulationGenetics stores them.
- ``ResultRecord`` — what a figure records about the analysis that made it (log text, analyst notes, data version), so it reads as a frozen result.
- ``StoredFigureView`` / ``FigureRow`` / ``FigureList`` / ``FigureTextEditor`` — showing a figure, listing a project's figures, and editing a figure's text.

### Platform-neutral types

- ``DLColor``, ``DLImage``, ``DLPasteboard`` — one name for what UIKit and AppKit each provide.
- ``MapBaseStyle`` / ``MapStylePicker`` — a map's base layer and the control that picks it.
- ``MapViewport`` — a map's visible area and scale, captured from a camera change.

### Matrix & Graph views

- ``MatrixView`` / ``MatrixEditorView`` / ``VectorView`` — SwiftUI views and editors for `Matrix` and `Vector` values.
- ``ConvexHull`` — the convex hull of a set of points, for area-coverage display.

Graph rendering (`GraphLayoutView`, `MapView`) lives in the `Graph` target itself, alongside the layout engine
that drives it.

### Analyses

- ``RegressionResult`` / `DateRegression` — regression fitting and results.
- ``PointCluster`` / `kMeansClustering` — k-means clustering.
- `anovaTable` / `hypergeometricScenarios` — standardized ANOVA output and hypergeometric scenario analyses.

### Media & export

- ``Media`` — a SwiftData-backed media model (requires Xcode's build system — see the package's `CLAUDE.md`).
- ``AnalysisResult`` / ``ResultImage`` — a stored analysis result plus its rendered image, for saving and export.
