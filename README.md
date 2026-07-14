# DyerLabFoundation Swift Analytics & Data Presentation Package
A foundation-tier Swift package providing matrix algebra, graph theory, SwiftUI data-presentation tools, and population-genetics analyses shared across Dyer Lab projects. It consolidates the former `MatrixStuff` and `PresentationZen` repositories, and now the `PopulationGenetics` package, into a single, dependency-ordered package.
## Products
| Product | Depends on | Purpose |
|---|---|---|
| `Matrix` | — | Linear algebra: matrices, vectors, operators, linear models, permutation tests, t-SNE, hypergeometric probability |
| `Graph` | `Matrix` | Generic graph theory: `Graph`, `Node`, `Edge`, adjacency, centrality, path-finding, and a force-directed layout engine |
| `PresentationZen` | `Matrix`, `Graph` | Charts, statistical analyses (ANOVA, clustering, regression), data tables, and all SwiftUI views for the above |
| `PopulationGenetics` | `Matrix`, `Graph`, `PresentationZen` | Genetic distance measures (Smouse-Peakall, pairwise ΦST), AMOVA, rarefaction, spatial and population-graph analyses, genotype data storage and I/O |
| `DyerLabFoundation` | all four | Umbrella target that re-exports everything via `@_exported import` |
`PresentationZen` is the UI layer for the whole package — any SwiftUI view for a `Matrix`, `Vector`, or `Graph` type lives there, regardless of which target defines the underlying type.
This is a horizontal foundation: `Matrix`, `Graph`, and `PresentationZen` stay domain-agnostic, with domain-specific logic isolated in `PopulationGenetics`. Generic types with no actual genetics content (AMOVA's underlying variance-decomposition machinery, distance-matrix storage, permutation-test engines, etc.) were promoted out of `PopulationGenetics` into `Matrix`/`PresentationZen` as part of the move — see the changelog below.
## Requirements
- Swift 6 (strict concurrency, `swiftLanguageModes: [.v6]`)
- iOS 17+ / macOS 14+
- Xcode's toolchain for building/testing (Command Line Tools lacks Swift Testing and SwiftData macro support):

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## Changelog

### 2026-07-14 — PopulationGenetics promoted into the package
- `PopulationGenetics` is now a target/product here (depends on `Matrix`/`Graph`/`PresentationZen`, re-exported from the umbrella), replacing the previous separate SPM package resolved via branch dependency.
- Ahead of the move, generic types with no actual genetics content were promoted from `PopulationGenetics` into `Matrix`/`PresentationZen`: `AMOVA`/`AMOVAResult`/`AMOVAPermutationProgress` (renamed `DistanceVarianceDecomposition`/`...Result`/`...Progress`), `DistanceMatrix<Kind>`/`PairwiseMeasure`/`PairwiseMatrix`, `SplitMix64`, `NullDistributionResult`, the open `AnalysisTag` type, generic `Resampling.permutationTest`/`subsampleTest` engines, `SymmetricUpperTriangle<Double>`, `String+NaturalSort`/`Array+Hashable.valueCounts()`, and a CoreLocation/MapKit utility set (`ConvexHull`, `DistanceBetween`, `MKCoordinateRegion`/`MKMapRect` helpers, coordinate array bounds/center).
- Domain-specific genetics logic (`Genetic/*`, `PopGenStore*`, genetic distance measures, simulation, population graphs) stays in `PopulationGenetics`.
- `.docc` resource processing for `PopulationGenetics` is deferred until the target builds cleanly in its new home.

### 2026-07-04 — AMOVA standardization & permutation testing
- Added `permutationTest.swift` and `PermutationTestResult` for significance   testing via permutation, applied to both AMOVA and regression.
- Added `fitLinearModel.swift` / `LinearModelFit` for standardized linear   model fitting.
- Added `anovaTable.swift` for standardized ANOVA output.
- Renamed `KeyValueTable` to `DataTableView`.

### 2026-07-04 — Hypergeometric probability
- Added `hypergeometricProbability.swift` (Matrix) and  `hypergeometricScenarios.swift` (PresentationZen) for hypergeometric  probability calculations and scenario-based analyses.

### 2026-06-25 — Documentation & cleanup pass
- Documented the full library in preparation for production integration.
- Removed the consolidation design brief now that the merge is complete.

### 2026-06-23 — Foundation conversion
- Converted the combined codebase into the `Matrix` / `Graph` /   `PresentationZen` / `DyerLabFoundation` product structure.

### 2026-06-22 — Initial consolidation
- Brought together `MatrixStuff` and `PresentationZen` into this repository.
