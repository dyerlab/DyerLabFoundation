# ``PresentationZen``

The SwiftUI presentation layer for `Matrix`: analysis charts, stored figures, data-table conversions and the
`Matrix`/`Vector` views.

## Overview

`PresentationZen` depends on `Matrix`, `Graph` and `PresentationZenCore`, and re-exports `PresentationZenCore`
(and through it `DyerlabCore`), so one import gives both. The charts, data tables, exports and platform-neutral
types that need neither `Matrix` nor `Graph` live in `PresentationZenCore`, where an app that only shows its data can
use them without the C++ `Matrix` library; they are written here as code spans, since they are documented there.
`Graph` owns its own SwiftUI views (`GraphLayoutView`, `MapView`) alongside its model and layout engine, so it has no
UI dependency on this target.

### Plots and their exports

- ``DataPlot`` — a `DataTable` drawn in a standard `PlotForm`. Other modules build the table and choose the form; the
  drawing and every export come from here.
- `DataTable.toR()` — the table as a tibble (`rSourceConvertible`). `DataTable.csvText` and
  `DataTable.tabSeparatedText` (`PresentationZenCore`) give it as text.
- ``RFigureChunk`` — ggplot2 code that redraws a plot, with its anchor and caption, to paste into an R chunk.
- `DataTable` conversions from a `Matrix`, a `NullDistributionResult` or a pairwise matrix, and transforms such as
  binning and box summaries (``BoxSummary``).

### Analysis charts

- ``Histogram``, ``BoxPlot``, ``ScatterPlotWithTrendline``, ``TemporalScatterPlot`` — chart views over a
  `DataTable`.
- ``NullDensityPlot`` / ``NullDistributionView`` — a finished permutation test: the null distribution with the
  observed value and P marked.
- ``PairwiseScatterPlot`` — draws a `Matrix` `PairwiseScatter` (the isolation-by-distance family of outcomes, including
  the forward and reverse pairs of directional isolation by graph distance): one colour per series, fitted lines, and
  a hover/tap tooltip naming each pair.

### Stored figures

- ``StoredFigure`` — a figure kept in a project file by any program: values (`FigureColumn`), how they're drawn, the
  generator that can recompute it (`FigureGenerator`), R code and pictures. It exports like a `DataPlot`, from
  whatever it holds. PopulationGenetics stores them.
- ``StoredFigureView`` / ``FigureRow`` / ``FigureList`` — showing a figure and listing a project's figures.
- ``RTableChunk`` — a results table as an R chunk; a ``StoredFigure`` of form `table` holds one.

### Logs and reports

- ``LogEntry`` — one entry of a project's log.
- `AnalysisReport.logEntries` — an analysis report (`Matrix`) as ``LogEntry`` values in manuscript order: the Methods
  passage (`.methods`), the notes, then the Results passage (`.results`), all tagged with the analysis's tag.

### Matrix views

- ``MatrixView`` / ``MatrixEditorView`` / ``VectorView`` — SwiftUI views and editors for `Matrix` and `Vector`
  values.
- ``MatrixHeatmap`` / ``MatrixHeatmapData`` — a distance or other square matrix as a heatmap, with runs of grouped
  rows marked; a directed matrix reads from row to column.

### Analyses

- ``RegressionResult`` / `DateRegression` — regression fitting and results.
- `anovaTable` / `nullDistributionTable` / `hypergeometricScenarios` — standardized ANOVA and permutation-test
  tables, and hypergeometric scenario analyses.
