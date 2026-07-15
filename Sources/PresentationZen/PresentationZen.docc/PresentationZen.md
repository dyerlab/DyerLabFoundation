# ``PresentationZen``

The SwiftUI presentation layer for `Matrix` and `Graph` — charts, statistical analyses, data tables, and views.

## Overview

`PresentationZen` depends on both `Matrix` and `Graph`: it is the UI layer for everything, regardless of which
target defines the underlying type. If a downstream package needs a SwiftUI view for a `Matrix`, `Vector`, or
`Graph` value, it lives here rather than alongside the type itself.

### Data tables

- ``DataTable`` — a generic, column-typed data table (``DataColumnRole``, ``ColumnKind``, ``PlotValue``) with CSV import/export and conversions from a `Matrix`, `NullDistributionResult`, or pairwise matrix.
- ``DataTableView`` — a SwiftUI view over a `DataTable`.
- ``PlotRow`` — a single row prepared for charting.

### Charts

- ``BarPlot``, ``BoxPlot``, ``DistributionPlot``, ``Histogram``, ``NumberLine``, ``PiePlot``, ``ScatterPlot``, ``ScatterPlotWithTrendline``, ``TemporalScatterPlot``, ``TimeSeriesPlot`` — chart views, all built on `DataTable` / `PlotRow`.

### Matrix & Graph views

- ``MatrixView`` / ``MatrixEditorView`` / ``VectorView`` — SwiftUI views and editors for `Matrix` and `Vector` values.
- ``GraphLayoutView`` — renders a `Graph` using the force-directed layout engine from `Graph`.
- ``MapView`` — a MapKit-backed spatial view, paired with ``ConvexHull`` for area-coverage display.

### Analyses

- ``RegressionResult`` / `DateRegression` — regression fitting and results.
- ``PointCluster`` / `kMeansClustering` — k-means clustering.
- `anovaTable` / `hypergeometricScenarios` — standardized ANOVA output and hypergeometric scenario analyses.

### Media & export

- ``Media`` — a SwiftData-backed media model (requires Xcode's build system — see the package's `CLAUDE.md`).
- ``AnalysisResult`` / ``ResultImage`` — a stored analysis result plus its rendered image, for saving and export.
