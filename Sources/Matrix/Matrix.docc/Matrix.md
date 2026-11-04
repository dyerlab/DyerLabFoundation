# ``Matrix``

Dense linear algebra and the general-purpose numeric foundations shared by every other product in this package.

## Overview

`Matrix` has no dependencies of its own — it is the base of the DyerLabFoundation product stack. `Graph`,
`PresentationZen`, and `PopulationGenetics` all build on it, and it stays domain-agnostic: nothing here knows
about graphs, charts, or genetics.

### Matrix & vector algebra

- ``Matrix`` — a dense, Accelerate-backed matrix type with Codable support and scalar/matrix operators.
- ``Vector`` — a `[Double]` typealias with numeric operators, binning, and natural-sort utilities.
- ``MatrixConvertible`` / ``VectorConvertible`` — conversion protocols for bridging other data shapes into a `Matrix` or `Vector`.
- ``rSourceConvertible`` — round-trips a value to R source, for scripting/export.
- `SingularValueDecomposition` / `MoorePenroseInverse` / `SymmetricEigendecomposition` — LAPACK-backed decompositions (the last matching R's `eigen(symmetric = TRUE)`, eigenvalues descending).

### Distance & variance

- ``DistanceMatrix`` / ``SymmetricUpperTriangle`` — symmetric pairwise-distance storage shared by every distance-based analysis downstream (genetic distance, spatial distance, relatedness).
- ``PairwiseMatrix`` / ``PairwiseMeasure`` — protocols a pairwise comparison type conforms to in order to plug into a `DistanceMatrix`.
- ``DistanceVarianceDecomposition``, ``DistanceVarianceDecompositionResult``, ``DistanceVarianceDecompositionProgress`` — AMOVA-style variance decomposition over a `DistanceMatrix`, with permutation-test progress reporting.

### Resampling & significance testing

- ``Resampling`` — generic permutation and subsample-test engines.
- ``NullDistributionResult`` / ``PermutationTestResult`` — the null-distribution and permutation-test result types shared across every domain that needs significance testing.
- ``AnalysisTag`` — an open tag identifying what a `NullDistributionResult` was computed for, so one result type serves every analysis.
- ``SplitMix64`` — a fast, seedable PRNG used wherever reproducible randomization is needed (permutation tests, simulation).
- `MoranSpectralRandomization` — Moran spectral randomization ("singleton", Wagner & Dray 2015): null replicates of a node-level variable that keep its mean, variance and spectral power on a weight matrix (gstudio's `msr_null()`; seeded draws match R's when the Moran eigenvalues are distinct).
- ``RMersenneTwister`` — a Mersenne-Twister that reproduces R's `set.seed()` / `runif()` / `sample()` bit-for-bit, for exact-parity testing of resampling ports against R.

### Analysis framework

- ``Analysis`` / ``AnalysisOutcome`` — the common interface for every analysis: a `Sendable` value holding its validated operands, run with ``AnalysisOptions`` (iterations and seed) to give an outcome that reports its statistic, comparison distribution, interval and p-value the same way across techniques.
- ``AnalysisType`` — an open catalogue of techniques, each listing its ``AnalysisOperand``s by role and ``AnalysisOperandKind``. Matrix defines `mantel`, `amova` and `rarefaction`; other modules add their own.
- ``MantelAnalysis`` / ``MantelOutcome`` — a port of vegan's `mantel()`, Pearson or Spearman (``CorrelationMethod``), matching R permutation by permutation for the same seed. Pairs with a non-finite response (e.g. `Inf` conditional genetic distance) are left out; named ``PairwiseMatrix`` operands are matched by group name.
- ``RarefactionAnalysis`` / ``RarefactionOutcome`` — rarefaction of any statistic over subsamples of a fixed size.
- ``PairwiseScatter`` / ``PairwiseSeries`` / ``PairwisePoint`` / ``RegressionLine`` — plot-ready pairwise points with fitted lines, produced by any ``PairwiseScatterRepresentable`` outcome (Mantel and the isolation-by-distance family) and drawn by PresentationZen's `PairwiseScatterPlot`.
- ``VarianceDecompositionAnalysis`` / ``VarianceDecompositionOutcome`` — ``DistanceVarianceDecomposition`` as an analysis (AMOVA, single-locus θ, 2Gener's Φ_FT differ only in the distances and tag).
- ``AnalysisReport`` / ``AnalysisReportTemplate`` / ``AnalysisNote`` / ``AnalysisRun`` — every analysis reports itself. `perform(options:)` runs it and fills its template's `{key}` placeholders: the Methods passage from the data and options, the Results passage from the estimates. The report also carries the notes recording decisions made about the data (values dropped or imputed). A placeholder without a value is left visible as `{key}`, and an app can pass its own template to change the wording. PresentationZen turns a report into log entries (`.methods`, the notes, then `.results`).

### Rasters

- ``Raster`` — a single-band `Float` grid, northernmost row first, with `Float.nan` for missing cells, laid out in longitude/latitude or in a UTM or Albers projection (``Raster/crs``). Point lookup by longitude/latitude, cropping to a study area or an ``RasterExtent``, ground cell sizes (``Raster/cellSize(atRow:)``) and conversion to a ``Matrix``. Categorical layers such as NLCD come in one class per raster.
- ``CoordinateReferenceSystem`` — geographic (EPSG:4326, 4269) or projected by a ``MapProjection``: Transverse Mercator (every UTM zone) or Albers equal-area, on an ``Ellipsoid`` (WGS 84 or GRS 80). Written without PROJ and matched to it to a millimetre. Recognises the common UTM and NAD83 Albers EPSG codes (``CoordinateReferenceSystem/init(epsg:)``), and reads and writes PROJ strings (``CoordinateReferenceSystem/init(definition:)``, ``CoordinateReferenceSystem/definition``) for exchange with R's `terra` and `sf`.
- ``GeographicBounds`` — a longitude/latitude box: a study area, buffered with ``GeographicBounds/buffered(by:minimum:)``, or the area a raster covers (``Raster/geographicBounds``). ``RasterExtent`` is the same box in a raster's own coordinates.
- ``importGeoTIFF(contentsOf:name:cropTo:)`` / ``importGeoTIFF(data:name:cropTo:)`` — reads a single-band GeoTIFF (classic or BigTIFF; stripped or tiled; uncompressed, LZW, Deflate or PackBits, with any predictor; 8–32-bit integers or 32/64-bit floats) in a supported coordinate system, by EPSG code or custom parameters, decoding only the blocks that overlap the crop area. Tested against files written by `terra`/GDAL. ``RasterImportError`` lists what it rejects.
- ``RasterColorRamp`` — colour ramps (`terrain`, `viridis`, `grayscale`) and ``RasterColorRamp/makeImage(raster:valueRange:)`` / ``RasterColorRamp/makeImage(raster:valueRange:width:height:cellIndex:)`` for drawing a raster as a `CGImage`, directly or resampled onto another grid.

### Resistance distances

- ``CellGraph`` — the graph of a resistance raster's cells on its own grid, joined to their ``CellGraph/Neighbours/four`` or ``CellGraph/Neighbours/eight`` neighbours. A step costs its ground length (the geodesic between cell centres, or grid metres) times the mean resistance of the two cells, as gdistance's `geoCorrection(type = "c")`. Missing cells are impassable. ``CellGraph/node(longitude:latitude:)`` places sites, ``CellGraph/leastCostDistances(from:to:)`` gives least-cost distances, and ``CellGraph/notes`` records how the graph was built and warns about coarse cells, high latitudes and cell counting.
- ``RandomizedShortestPaths`` — randomized-shortest-path distances at a given θ: ``RandomizedShortestPaths/Measure/freeEnergy``, ``RandomizedShortestPaths/Measure/expectedCost`` or ``RandomizedShortestPaths/Measure/netExpectedCost``, matching gdistance's `rSPDistance()`. The reference walk can be area-corrected on longitude/latitude rasters (``CellGraph/ReferenceWalk/areaCorrected``, the default) without changing step costs.
- ``Ellipsoid/distance(fromLongitude:latitude:toLongitude:latitude:)`` — the geodesic distance between two points (Vincenty).

### Regression & probability

- ``LinearModelFit`` — standardized linear-model fitting.
- `pearsonCorrelation` / `studentTCDF` / `studentTTwoSidedPValue` / `regularizedIncompleteBeta` — Pearson correlation and the Student's t distribution behind it, matching R's `cor.test(method = "pearson")`.
- `spearmanCorrelation` / `averageRanks` — Spearman's rank correlation on average ranks, matching R's `cor(method = "spearman")`.
- ``SigmaSearchResult`` — result of a bandwidth/sigma search (used by t-SNE affinity tuning).
- `tSNEAffinity` / `pairwiseTSNEAffinities` — t-SNE affinity calculation for embedding high-dimensional data.
- `hypergeometricProbability` — hypergeometric probability calculations.
