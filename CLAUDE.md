# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Use Xcode's toolchain — Command Line Tools lacks Swift Testing and SwiftData macros
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MatrixTests
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter GraphTests
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift package resolve
```

Alternatively: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` once, then plain `swift build` / `swift test`.

This path has moved before (was `/Users/rodney/Downloads/Xcode-beta.app` as of 2026-08-xx; back to `/Applications/Xcode-beta.app` as of 2026-08-31; Xcode-beta gone and release `/Applications/Xcode.app` used as of 2026-10-23) — if `swift build` fails with "missing DEVELOPER_DIR path", run `mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'"` to find its current location rather than assuming it's gone.

## Working conventions

These were agreed with the user over many sessions. They also live in Claude's per-machine memory, which doesn't
travel between workstations, so they're repeated here.

- **Commits and versions:** the user makes every commit. Leave changes uncommitted and don't offer to commit.
  Don't create or suggest version tags unless asked.
- **Sole developer:** the user is the only developer on this package and its consumers (Linguistics,
  GeneticStudio, gstudio). Flag breaking changes, but their "confirmed compatible" is enough; no feature-branch
  gating is needed.
- **Thoroughness over speed.** Ground every claim in the code you've read. Raise genuine judgment calls as
  questions, bundled together rather than one at a time. Architecture discussion counts as part of the work.
- **R parity:** R parity is checked with fixtures that R scripts write to `Tests/*/Fixtures/`.
  - Where the R code is gstudio's own (with `RMersenneTwister`), parity is bit-exact.
  - Where exact parity would mean porting a third-party library's internals (igraph, for example), functional
    equivalence is fine: port the documented algorithm, and test invariants plus statistical agreement.
- **Extensible categories** use open string-backed structs (`AnalysisTag`, `LogType`, `AnalysisType`), not
  closed enums.
- **SwiftUI:** keep views shallow. Avoid single-child wrapper containers, and extract blocks repeated 3+ times into
  small subviews, so Xcode previews keep working.
- **Swift Coding Protocol** (the user's Bear note): a file header, one declaration per file, DocC on every public
  symbol, Swift Testing, `LocalizedError`, and previews for views. Analyses return `nil` from a failable init;
  they don't throw.
- **Plans not yet started:** the gravity-field plot (`GravityFieldPlan.md` in the repo root; the renderer is still
  the user's call: 2D `Canvas` or RealityKit) and a multi-topology "chromosome walk" persistence schema (deferred
  until that app exists).

## Current state and next steps (handoff, 2026-11-04)

**Everything since commit `fb7b8b9` is uncommitted.** That covers four pieces of work:
- the GeoTIFF reader and `Raster` (2026-11-03);
- the `.rasters` ProjectStore component;
- `RasterMapView`, the Baja elevation demo tab and `RasterOpacitySlider`;
- native UTM/Albers projections and the RSP work (2026-11-04).

`git status` lists all of it. The full suite passed, with 866 tests:

| Target | Tests |
|---|---|
| DyerlabFoundation | 101 |
| Matrix | 398 |
| Graph | 221 |
| PresentationZen | 129 |
| (one-test bundle) | 1 |
| PopulationGenetics | 16 |

Matrix built for the iOS and visionOS simulators, and DocC had 0 diagnostics.

**Environment notes for a new machine**
- R fixture scripts need `terra`, `jsonlite` and, for `generate_rsp_fixtures.R`, `gdistance` (1.6.5 was used).
  Install with `install.packages("gdistance")`. The committed JSON fixtures mean R is only needed to regenerate
  them.
- `swift test -c release` doesn't build, because `PopulationGeneticsPreviewData` is debug-only. Time things in a
  debug build or in a standalone `swiftc -O` script.

**Next steps for the RSP work** (see "Resistance distances" below for what exists):
1. An `Analysis` conformer for RSP distances, with a `reportTemplate` and the `CellGraph.notes` carried into the
   report.
2. A helper that averages the directed `[i][j]`/`[j][i]` distances into a symmetric matrix for `MantelAnalysis` and
   IBGD.
3. Fitting θ and resistance contrast against population graphs: the edge-tension objective from the user's note,
   "Randomized Shortest Paths (RSP) and the θ Parameter.pdf", in the repo root (git-ignored, so copy it across by
   hand). One feature-wise surface r = 1 + s·x at a time, over a grid of (log θ, log contrast).
4. **Choose a better worked example with the user.** The bundled Baja DEM / arapat isn't suitable: it stops at
   30° N, which cuts the peninsula off from Sonora.

Other open items:
- Lambert conformal conic (Mexico/INEGI's EPSG:6372) is still rejected. It would be about the same effort as Albers.
- The analysis-template citations were written from memory and need checking before publication.

## Architecture

DyerLabFoundation is a **foundation-tier Swift package** consolidating `MatrixStuff` and `PresentationZen` into a single repo. It exposes four library products plus an umbrella:

| Product | Depends on | Purpose |
|---|---|---|
| `Matrix` | — | Linear algebra: matrices, vectors, operators, t-SNE, PCA, `rSourceConvertible` protocol |
| `Graph` | `Matrix` | Generic graph theory: Graph, Node, Edge, Adjacency, Centrality, Path + full force-directed layout engine + its own SwiftUI views (GraphLayoutView, MapView) + file import (.pgraph, GeoJSON) |
| `PresentationZen` | `Matrix`, `Graph` | Charts, analyses, data-communication helpers, SwiftUI views for Matrix/Vector and general data-communication (charts, tables) |
| `PopulationGenetics` | `Matrix`, `Graph`, `PresentationZen` | Diploid genetic-marker storage/import/analysis (see below — folded in wholesale as of 2026-07-14) |
| `DyerLabFoundation` | all four | Umbrella — re-exports everything via `@_exported import` |

### PresentationZen is the UI layer — except Graph, which owns its own views

All SwiftUI views for `Matrix`/`Vector` (plus general data-communication views: charts, tables, analyses) live in PresentationZen — import `PresentationZen` for those. `Graph` is a deliberate exception (as of 2026-08-08): its views (`GraphLayoutView`, `MapView`, `NodeInspectorForm`, under `Sources/Graph/Views/`) live alongside its model and force-directed layout engine rather than in PresentationZen, because a graph's rendering is inseparable from the layout-simulation state that drives it. `PresentationZen` still depends on both `Matrix` and `Graph` (for the layout engine and non-view types it re-uses), but no longer supplies Graph's SwiftUI views — code that imported `PresentationZen` only to reach `GraphLayoutView`/`MapView` must now `import Graph` instead.

### Source layout

```
Sources/
  Matrix/          — Matrices/, Vectors/, Algorithms/, Analysis/, Protocols/, Types/, Raster/, Resistance/,
                     Operators.swift
  Graph/           — Models/{Graph,Node,Edge,Path}.swift, Extensions/{Adjacency,Centrality}.swift
                     Extensions/  ← also the downstream popgraph-analysis ports (domain-neutral, so
                                    here not in PopulationGenetics): GraphAsymmetries, AsymmetricWeights /
                                    AsymmetricPopulationGraph, CongruenceTopology / TestCongruence,
                                    Graph.subtractingEdges, GraphNeighborhood (undirected helpers);
                                    RandomizeGraph + AsymmetryBandwidthTest / AsymmetryNetworkTest /
                                    AsymmetrySignificance (seeded resampling, via Matrix's RMersenneTwister
                                    which reproduces R's set.seed()/sample() bit-for-bit) — synced to
                                    gstudio 1.15.0 (2026-10-06). Numerically identical to R except
                                    RandomizeGraph(.degree): gstudio 1.15 switched to
                                    igraph::rewire(keeping_degseq()), ported *functionally* (same
                                    Maslov-Sneppen edge-swap chain, 10·E attempts, loops/multi-edges
                                    rejected) rather than draw-for-draw — so it and AsymmetryNetworkTest
                                    are tested by invariants + statistical agreement with R's null, not
                                    exact identity. Paired R↔Swift fixtures: regenerate with
                                    Tests/GraphTests/Fixtures/generate_downstream_fixtures.R; gstudio's
                                    tests/testthat/test-swift-parity.R asserts the R side.
                                    GeneticGravity.swift ← gstudio 1.15's genetic-gravity core:
                                    NeighbourhoodWeights / GravityEdges / SourceSinkScores /
                                    PartitionedGeneticDistance(Graph) (neighbourhood_weights(),
                                    gravity_edges(), source_sink_scores(), pgd()) — deterministic,
                                    matches R to 1e-10 (Fixtures/generate_gravity_fixtures.R).
                                    SourceSinkTest / IsolationByGraphDistance /
                                    DirectionalIsolationByGraphDistance ← source_sink_test(), ibgd()
                                    (split by mode); Moran spectral randomization (msr_null()) lives in
                                    Matrix as MoranSpectralRandomization. Seeded draws match R exactly:
                                    each MSR replicate Σ s_k r_k v_k is invariant to eigenvector sign
                                    (r_k = cor(z, v_k) flips with v_k), so only eigenvalue *order*
                                    matters — exact while eigenvalues are distinct, distributional
                                    within a repeated eigenvalue. gravity_field()/plotting are R-only.
                     Layout/{Camera,Core,Simulation}/
                             Core/KamadaKawai.swift ← igraph layout_with_kk() port (LayoutAlgorithm.kamadaKawai,
                             selectable alongside Fruchterman–Reingold; gstudio's layout = "kk" is the default
                             weighting). Exact R parity for the first 100 moves; on graphs still moving at 50·n
                             moves, igraph's C FMA rounding sends it down a different but equally good path, so
                             arapat is tested functionally (energy + per-component Procrustes). Fixtures:
                             Tests/GraphTests/Fixtures/generate_layout_fixtures.R.
                     Views/  ← GraphLayoutView (composition root), GraphCanvasView, GraphControlPanel,
                               GraphInspectorPanel, GraphLayoutOptions, MapView, NodeInspectorForm
                               Reality/  ← RealityGraphView, RealityGraphEntityBuilder, RealityGraphOptions
                                          (RealityKit-based 3D visualization; the intended long-term
                                          replacement for GraphCanvasView across iOS/macOS/visionOS — see
                                          realitykit_unification_decision)
                     IO/     ← file import: importPGraph, importGeoJSON, GraphExampleData
                     Data/   ← bundled example graph files (lopho.pgraph, lopho.geojson)
  PresentationZen/ — Analyses/, Charts/, Extensions/, Models/, Protocols/, Tables/, Views/
                     MatrixViews/    ← Matrix + Vector SwiftUI views
  PopulationGenetics/ — Genetic/, DataStore/, Persistence/, Simulation/, PopulationGraph/,
                     Algorithms/, Models/, Protocols/, Types/, Extensions/, Views/, ExampleData/
                     PopulationGraph/  ← also Phase 2b of the downstream popgraph-analysis port
                                          (genotype-driven, so here rather than Graph's Extensions/):
                                          AsymmetryPermutationTest / AsymmetryCI / PermutePopgraph
                                          ← asymmetry_permutation() / asymmetry_ci() (replaced
                                          asymmetry_jackknife() in gstudio 1.15) / permute_popgraph(),
                                          each re-estimating PopulationGraph() per draw via RMersenneTwister
                                          (bit-exact R parity) + GraphAsymmetries (Graph). Synced to gstudio
                                          1.15.0 (null-centred location test, asymmetry_ci). Fixtures:
                                          Tests/PopulationGeneticsTests/Fixtures/generate_asymmetry_fixtures.R.
                                          PartitionedGeneticDistance(data:groups:gamma:) ←
                                          genetic_distance(mode = "pgd"), verified end to end on gstudio's
                                          `gravity` genotypes (Fixtures/gravity_genotypes.csv).
                                          LocusSubsampleNull ← locus_subsample_null(), also exact.
                                          Earlier: permute_popgraph()'s per-stratum resampling was fixed
                                          2026-09-11 (see gstudio-source-is-canonical-reference memory) to plain
                                          sample(replace=TRUE) instead of sampling::strata(method="srswr"), which
                                          both mis-paired resampled rows with the original unsorted groups vector
                                          on non-stratum-sorted input and wasn't RNG-parity-portable.
  DyerlabFoundation/ — DyerlabFoundation.swift (@_exported imports)
Tests/
  MatrixTests/          GraphTests/          PresentationZenTests/
  PopulationGeneticsTests/   DyerlabFoundationTests/
```

### PopulationGenetics: folded in wholesale (2026-07-14), superseding the earlier promotion pass

Earlier the same day, a "promotion pass" lifted specific domain-neutral types (AMOVA's variance decomposition,
`DistanceMatrix`, `SplitMix64`, `NullDistributionResult`/`AnalysisTag`, resampling engines, `AnalysisResult`,
spatial utilities) out of the standalone `PopulationGenetics` package into Matrix/Graph/PresentationZen, on the
premise that this repo stays domain-neutral and genetics-specific code (`Genetic/*`, `DataStore/PopGenStore*`,
`GeneticDistances/*`, `Simulation/*`, `PopulationGraph/*`) lives only in that separate package.

That premise no longer holds: the `feature/populationgenetics-target` merge (`d4e2082`/`91769d7`) copied the
*entire* `PopulationGenetics` source and test tree into this repo as a fourth product, and the umbrella now
re-exports it (`@_exported import PopulationGenetics` in `DyerlabFoundation.swift`). This was a deliberate
decision, confirmed 2026-07-14: **`Sources/PopulationGenetics/` in this repo is now canonical.**

- The standalone `github.com/dyerlab/PopulationGenetics` repo is **legacy** — do not push further changes there;
  port fixes into this repo's `Sources/PopulationGenetics/` instead. It was tagged `1.1.0` immediately before this
  decision (adding `ExampleDataset` + bundled resources at `Sources/PopulationGenetics/ExampleData/`), and that
  work was re-applied here in the same session — the two trees are in sync as of that tag, but will drift from
  here on since only this repo should receive further edits.
- Downstream consumers that used to depend on the standalone package (e.g. GeneticStudio, once its Xcode project
  is wired up correctly — see the Downstream consumers section) should instead depend on the `PopulationGenetics`
  product of the `dyerlabfoundation` package, or just the `DyerLabFoundation` umbrella.
- The "horizontal foundation, no domain-specific code" framing for `Matrix`/`Graph`/`PresentationZen` still holds
  for *those three* products — `PopulationGenetics` is explicitly the domain-specific exception living alongside
  them in the same repo, not an argument for putting genetics code inside `Matrix`/`Graph`/`PresentationZen`
  themselves.

### Analysis framework (2026-11-02)

Analyses share one interface, defined in `Sources/Matrix/Analysis/`, because every one of them takes matrices or vectors:
- `Analysis` is a `Sendable` value holding already-checked inputs. Its failable `init` returns `nil` on unusable input
  (per the Swift Coding Protocol, analyses don't throw). `run(options: AnalysisOptions)` takes `iterations` and `seed`
  and returns an `AnalysisOutcome?`.
- `AnalysisOutcome` reports `statistic`, `distribution` (`NullDistributionResult?`, either a permutation null or
  resampled estimates), `interval`, `testDirection` and `pValue`. Outcomes that aren't tests (rarefaction, outcrossing,
  correlated paternity, directional IBGD) return `nil` for `pValue`.
- `AnalysisType` (the technique, with its `operands`) and `AnalysisOperandKind` are **open string-backed structs, not
  enums**, so modules above Matrix can add their own with `static let` extensions:
  - Matrix: `.mantel`, `.amova`, `.rarefaction`
  - PopulationGenetics: `.outcrossing`, `.correlatedPaternity`, `.isolationByDistance`
  - Graph: `.isolationByGraphDistance`, `.directionalIsolationByGraphDistance`
  `AnalysisTag` is still the open label for a particular *use* of a technique (`.amovaPhiST` vs `.weirCockerhamTheta`).
- Conformers by target:
  - Matrix: `MantelAnalysis`, `VarianceDecompositionAnalysis`, generic `RarefactionAnalysis<Unit>`
  - PopulationGenetics: `AMOVAAnalysis` (an alias), `DiversityRarefactionAnalysis`, `OutcrossingAnalysis`,
    `CorrelatedPaternityAnalysis`, `IsolationByDistanceAnalysis`
  - Graph: `IsolationByGraphDistanceAnalysis`, `DirectionalIsolationByGraphDistanceAnalysis`. The legacy
    `IsolationByGraphDistance(...)`/`DirectionalIsolationByGraphDistance(...)` functions now delegate to these.
- `MantelAnalysis` is a port of vegan's `mantel()`. It permutes the *predictor* (vegan's first argument) using
  `RMersenneTwister`, so it matches vegan permutation by permutation for n ≥ 8 (smaller n is fully enumerated by
  vegan). It skips pairs whose response isn't finite (`Inf` cGD between disconnected nodes). Fixtures:
  `Tests/MatrixTests/Fixtures/generate_mantel_fixtures.R`.
- `TwoGenerAnalysis` (PopulationGenetics, `Algorithms/TwoGener/`) follows Smouse et al. (2001) eqs. 1–7: each paternal
  gamete is an allele vector and d² = ½Σ(Y_g − Y_h)² summed over loci. Decisions confirmed with the user on 2026-11-02:
  - Pollen-pool frequencies are estimated study-wide, never per mother. The default is EM; `.paternalAverage` (an
    ambiguous gamete counts ½ to each candidate) is the original 2Gener/GenAlEx estimate, kept as an option.
  - A missing mother or offspring genotype at a locus is imputed as the pollen-pool frequency vector.
  - An offspring incompatible with its mother at *any* locus is dropped entirely.
  - Every decision is an `AnalysisNote` (`.assumption`/`.warning`) in `TwoGenerAnalysis.notes`, carried into the
    report by `perform(options:)` and persisted with `ProjectStore.appendLog(report:)`.
  The source papers (Smouse et al. 2001; Dyer et al. 2004, StAMOVA) are kept as local PDFs in the repo root, which
  `.gitignore` excludes.
- Every analysis reports itself (added 2026-11-02 at the user's request: the log should hold manuscript-ready text
  for every run). `Analysis` requires `static var reportTemplate` (an `AnalysisReportTemplate` of Methods and Results
  text with `{key}` placeholders) and `methodsValues(options:)` (values from the data and options), with optional
  `notes: [AnalysisNote]` for decisions made about the data. `AnalysisOutcome` requires `resultsValues` (values from
  the estimates). `perform(options:template:)` returns an `AnalysisRun` (outcome + `AnalysisReport`). A missing value
  stays visible as `{key}`. Common keys: `analysis`, `tag`, `iterations`, `seed`, `statistic`, `pValue`, `interval`.
  Use `AnalysisReport.number/count/pValue/permutationSentence/sentenceCase` so all reports format alike. Each
  conformer's template lives in `<Type>+Report.swift`; wrappers (IBD, IBGD, TwoGener) reuse their inner Mantel/AMOVA
  values and set its labels (`responseLabel`, `statisticLabel`, `unitLabel`, ...). PresentationZen's
  `AnalysisReport.logEntries` gives `.methods`, the notes, then `.results` (new `LogType`s);
  `ProjectStore.appendLog(report:)` writes them in one transaction. The citations in the templates were written from
  memory, so check them before publishing. In particular, BORICE is cited as Koelling, Monnahan & Kelly 2012, while
  the `OutcrossingMath.swift` comment says "Ritland & Ritland's BORICE".
- Pairwise outcomes conform to `PairwiseScatterRepresentable` and expose a `PairwiseScatter` (series of `PairwisePoint`
  plus a `RegressionLine`), which PresentationZen's `PairwiseScatterPlot` draws.

### Rasters (2026-11-03; projections 2026-11-04)

`Sources/Matrix/Raster/` holds `Raster` (a `Sendable` struct, not a `Matrix` subclass: single band, `[Float]`
row-major with the northernmost row first, `Float.nan` = missing, laid out over a `RasterExtent` in a
`CoordinateReferenceSystem`), `GeographicBounds`, `RasterColorRamp`, the projections (`MapProjection`, `Ellipsoid`),
and a self-contained GeoTIFF reader (`importGeoTIFF`, `TIFFFile`, `TIFFImageLayout`, `TIFFDecompression`,
`GeoKeyDirectory`, `GeoTIFFGeoreference`). Decisions confirmed with the user:
- Univariate only. Categorical data such as NLCD comes in one class per raster layer; multi-band files are rejected.
- Coordinate systems, with no PROJ/GDAL dependency (PROJ would add about 15 MB per app plus XCFramework
  maintenance on five platforms; decided 2026-11-04):
  - Geographic: EPSG:4326 or EPSG:4269. Datum shifts are ignored (1–2 m).
  - Projected in metres: Transverse Mercator (UTM) and Albers equal-area, written natively. TM uses Karney's
    (2011) order-6 Krüger series, not Snyder's (which loses millimetres a few degrees off the central meridian).
    Albers uses Snyder (1987) on the ellipsoid. Both match PROJ to under 1 mm forward and 1e-9° inverse
    (`Fixtures/generate_projection_fixtures.R`, 12 systems including a southern cone and a single-parallel cone).
  - Recognised EPSG codes are in `MapProjection+EPSG.swift`: WGS 84, NAD83, NAD83(2011) and ETRS89 UTM, and NAD83
    Albers for CONUS (5070 is NLCD's), Alaska, California and BC. User-defined TM/Albers GeoKeys are read too, and
    GDAL puts Albers' origin in the natural-origin keys. Anything else (e.g. Mexico's LCC, EPSG:6372, which is
    INEGI's) is rejected with a hint to `terra::project()` first. Lambert conformal conic would be about the same
    effort as Albers if Baja/INEGI data need it.
  - Projected rasters keep their own grid; nothing is resampled on import. `cropTo:` projects the study area and
    takes the enclosing grid rectangle.
  - `CoordinateReferenceSystem.definition` is "EPSG:n", or a PROJ string for a code-less projection, so it can be
    passed straight to terra/sf as `crs`. `init(definition:)` parses both.
- Rasters are cropped on import (`cropTo:`, usually `graph.studyArea()`, a 10% buffered box); only the overlapping
  strips/tiles are decoded. The reader handles classic/BigTIFF, strips/tiles, none/LZW/Deflate/PackBits,
  predictors 2/3, 8–32-bit ints and 32/64-bit floats, and GDAL_NODATA. Fixtures:
  `Tests/MatrixTests/Fixtures/generate_geotiff_fixtures.R` (terra writes each layout, including UTM, CONUS Albers
  and custom TM/Albers; tests compare cell by cell), plus `geotiff/alt_baja.tif`, a real WorldClim 30-arc-second DEM
  of Baja California, checked against terra whole, cropped to the arapat study area, and at each arapat population.
  The projected crop boxes avoid edges that land exactly on cell boundaries, because terra snaps lower and upper
  edges there with different tolerances.
- `Raster.cellSize(atRow:)` gives ground sizes because 4326 cells aren't square. A projected raster returns its grid
  metres, which carry the projection's own scale error (<0.1% in a UTM zone, up to ~1.3% for CONUS Albers).
  Resistance modeling (planned) must use it rather than counting cells.
- Display: `RasterMapView` (Graph/Views) wraps `MKMapView` because SwiftUI `Map` has no image overlay.
  `RasterOverlay` resamples each pixel of a Web Mercator grid over `Raster.geographicBounds` to the cell under it
  (nearest neighbour), which handles geographic and projected rasters alike.
- Persistence: the `.rasters` `StoreComponents` case (`ProjectStore+Rasters.swift`). Layers are keyed by name and
  replaced in place, unlike `.matrices`. `data` is a little-endian Float32 blob, the extent columns are in the
  layer's own units, and `crs` is the definition text, so gstudio can rebuild a `terra` raster in R with
  `crs = row$crs` without this package. The recipe is in `RastersSchemaComponent.swift`'s header (verified with
  RSQLite + terra for geographic layers on 2026-11-03, and for EPSG and custom projected layers on 2026-11-04).
  Change that layout only together with gstudio's reader.

### Resistance distances (2026-11-04)

`Sources/Matrix/Resistance/` builds a `CellGraph` from a resistance `Raster` on the raster's own grid (no
reprojection) and computes least-cost and randomized-shortest-path (`RandomizedShortestPaths`) distances between
sites. Decisions confirmed with the user:
- A step costs its ground length times the mean resistance of the two cells, which is gdistance's
  `transition(r, function(x) 1/mean(x))` followed by `geoCorrection(type = "c")`. Lon/lat lengths are Vincenty
  geodesics between cell centres (`Ellipsoid.distance`), matching raster::pointDistance to under 1e-9. Projected
  rasters use grid metres. `.cellSteps` (1 and √2) is an option for gauging the bias. 8 neighbours by default.
  Missing or infinite cells are impassable; separate regions give `.infinity`.
- The reference walk is `.areaCorrected` by default: steps between rows are also weighted by cos(latitude), as
  geoCorrection type "r" does, but **only in the walk, not the costs**. Stock gdistance can't do this, because its
  type "r" stretches the costs too. `.conductance` reproduces stock `rSPDistance()` after type "c" exactly.
- Each destination is absorbing (its row of W is zeroed) and solved on its own region, so I − W stays well
  conditioned as θ → 0. Measures: `.freeEnergy` (−log z/θ, one solve per destination), `.expectedCost` (gdistance
  "total") and `.netExpectedCost` (gdistance "net"). Distances are directed. θ = 0 is allowed except for free
  energy. Underflow at large θ returns `nil` rather than `.infinity`.
- `CellGraph.notes` are `AnalysisNote`s: assumptions, plus warnings for multiple regions, cells ≥ 0.5°, latitude
  beyond 60°, and cell counting (with the 1 − cos φ bias).
- Solver: `SparseSquareSystem` uses Accelerate sparse LU (QR before macOS 15.5/iOS 18.5/visionOS 2.5). Two LU bugs
  were found on macOS 27.2 and worked around: multi-column *transposed* solves give wrong columns after the first
  (so they're solved one column at a time), and concurrent LU factorizations segfault (so all factorizations are
  serialised by a lock). LU is still about 3× faster than QR at 360k cells. A 128k-node Baja graph takes about
  0.25 s per destination.
- Fixtures: `Tests/MatrixTests/Fixtures/generate_rsp_fixtures.R` (gdistance 1.6.5), with UTM queen/rook and lon/lat
  grids at 30° N and 60° N. It checks step costs, costDistance and all three measures for both walks at several θ
  to 1e-8. Resistances are multiples of 1/8 so Float32 holds R's doubles exactly. The θ limits (θ = 0 gives the
  walk's expected hitting cost; large θ gives least cost, decreasing monotonically) are tested against independent
  dense and Dijkstra solutions.
- Not done yet: an `Analysis` conformer, θ/contrast fitting against population graphs, and a worked example. The
  bundled Baja DEM is unsuitable as the example because it stops at 30° N, which cuts the peninsula off from
  Sonora; a better example is still to be chosen.

### Swift version & platforms

Swift 6 strict concurrency (`swiftLanguageModes: [.v6]`) with `.enableUpcomingFeature("ApproachableConcurrency")` on all targets. Platforms: `.iOS(.v18), .macOS(.v15), .visionOS(.v2)` (raised from `.iOS(.v17), .macOS(.v14)` on 2026-08-09 to add visionOS and support `RealityGraphView`'s `RealityView`/`PhysicsDistanceJoint` usage — those APIs require exactly this floor). No per-symbol `@available` gating is needed anywhere in the package as a result, since every target's minimum already matches.

### `#Preview` guards — removed (2026-08-08)

`#Preview` macros used to be wrapped in `#if !SPM_BUILD` / `#endif`, with `SPM_BUILD` defined unconditionally in every target's `swiftSettings`. That define applies to *any* build of this manifest — including Xcode's — so the guard was permanently suppressing previews in Xcode too, not just in CLI builds as intended; removed once that was noticed. `#Preview` genuinely does fail under the bare Command Line Tools toolchain (`external macro implementation type 'PreviewsMacros.SwiftUIView' could not be found`, confirmed 2026-08-08), but this repo already mandates the full Xcode toolchain for `swift build`/`swift test` regardless (see Commands, above) for Swift Testing/SwiftData macro support — so that toolchain gap was never actually reachable through this project's supported workflow.

### SwiftData note

`PresentationZen/Models/Media.swift` uses SwiftData's `@Model` macro. This macro plugin is only resolved by Xcode's build system — build `PresentationZen` from Xcode. `Matrix` and `Graph` build and test cleanly from the command line.

### DocC documentation

Every target (`Matrix`, `Graph`, `PresentationZen`, `PopulationGenetics`, `DyerlabFoundation`) has a `.docc`
catalog (`Sources/<Target>/<Target>.docc/`) with a hand-written landing page (`Info.json` + `<Target>.md`, titled
`# ``<Target>`` `) giving a one-line abstract and an overview of the target's key public types. All are wired
into `Package.swift` via `resources: [.process("<Target>.docc")]` — none are excluded/deferred anymore. When
adding a landing-page symbol link, only double-backtick-link symbols that belong to the *same* target being
documented; link other targets' symbols with plain code spans (single backticks) instead, since a single
`docc convert` pass only has that one target's symbol graph in scope and cross-module double-backtick links there
resolve unreliably (verified 2026-07-15 by running `xcrun docc convert` against each target's own symbol graph
and checking the diagnostics file was empty). There is no `swift-docc-plugin` dependency in this package — that's
only needed for CLI-driven `swift package generate-documentation`/hosting; Xcode's own "Build Documentation" and
the `xcrun docc convert` verification method above don't need it.

All five catalogs convert with zero diagnostics as of 2026-10-23 (the six old `PresentationZen/Analyses` link
warnings are gone). To re-verify: `swift package dump-symbol-graph --minimum-access-level public`, copy
`.build/out/symbolgraph/<Target>.symbols.json` plus its `<Target>@*.symbols.json` extension graphs into a
per-target directory, then `xcrun docc convert Sources/<Target>/<Target>.docc --additional-symbol-graph-dir <dir>
--diagnostics-file <file>`.

### Design document

`DyerLabFoundation-Consolidation.md` in the repo root is the original design brief — read it before making structural changes to targets or the Package.swift manifest.

### Downstream consumers

**Swift Coding Protocol compliance pass (2026-10-23)** — the package was brought in line with the "Swift Coding
Protocol" note (Bear). That pass included these source-breaking renames, which every consumer must absorb:
- Matrix: `permutationTest(designMatrix:response:permutations:)` → `PermutationTest(...)` (the
  `Resampling`/`DistanceVarianceDecomposition` methods named `permutationTest` are unchanged);
  `StandardNormalQuantile`/`ChiSquareQuantileOneDF`/`EmpiricalQuantile` → lowerCamelCase.
- PresentationZen: `dateRegression` → `DateRegression`; `LoadFromAsset`/`DistanceBetween` → `loadFromAsset`/
  `distanceBetween`.
- PopulationGenetics: `rarefaction`/`genotypicRarefaction`/`allelicRarefaction`/`pairwisePhiST` → UpperCamelCase;
  `GenotypePlaccard` → `GenotypePlacard`; the `leftLingage:` label → `leftLineage:`.
- `PopulationGraphDataset.graph` is now a `Sendable` `GraphSnapshot` (Graph) instead of a live `Graph` — call
  `dataset.makeGraph()`. `ProjectStore.writeGraph` still accepts a `Graph` through a `nonisolated` overload that
  snapshots it on the caller's actor. `Graph`/`Node`/`Edge` deliberately stay non-`Sendable` reference types;
  `GraphSnapshot` is the boundary type, just as `Data` is for `Matrix`.
- `PopulationGeneticsPreviewData` is now `@MainActor`.
- `MapView` (Graph) gained a public `init(graph:lineWidth:nodeScaling:)`. Before this it had no public
  initializer and couldn't be constructed outside the module.

**Project metadata (2026-10-24)** — `ProjectStore` files carry a `project_metadata` table of string key/value
pairs, part of every file (not a `StoreComponents` case). It holds the reserved identity keys in
`ProjectStore.MetadataKey` (`project_name`, `species`, `description`, moved out of `meta`) plus any keys an app
adds; `meta` is now purely the store's own bookkeeping (`created_at`, schema versions, `has_*` flags, counts). API:
`metadata()`, `metadata(forKey:)`, `setMetadata(_:forKey:)`, `updateMetadata(_:)` (one transaction; `nil`/empty
removes a key; removing `project_name` throws the new `PersistenceError.invalidMetadata`). `create`/`openOrCreate`/
`saveSnapshot` take `metadata:`; `ProjectSnapshot` gained `metadata` and its identity fields are now computed from
it. No migration: files written before this have no `project_metadata` table and won't read (sole-developer
project, no legacy files to support).

Linguistics (Matrix + PresentationZen) is affected by the Matrix and PresentationZen renames above.

- **PopulationGenetics** — no longer a separate downstream consumer; folded into this repo as of 2026-07-14 (see above). The standalone `github.com/dyerlab/PopulationGenetics` repo is legacy.
- **Linguistics** — uses `Matrix` + `PresentationZen`; resolves `dyerlabfoundation` off `branch: "main"`, not a version tag. Migration to consume newer foundation APIs deferred, but a broken `main` here breaks this too — land nontrivial foundation changes on a feature branch and verify against real downstream consumers before merging. The platform-floor bump to iOS 18/macOS 15/visionOS 2 for `RealityGraphView` (2026-08-09) raises this for the *whole package*, including `Matrix`/`PresentationZen` — Linguistics tracks `main` directly, so it inherits this floor immediately with no opt-out. Confirmed compatible across all downstream artifacts/projects (2026-08-09) — sole-developer setup, verified directly rather than through a feature-branch check.
- **GeneticStudio** — a new app being built directly against this foundation as it evolves; not a stability concern, expected to simply conform. Its Xcode project currently only references the `dyerlabfoundation` package (no separate `PopulationGenetics` dependency), even though its own source already calls PopulationGenetics-only types (`ImportedDataset`, `ProjectStore`, `importMicrosatTable`) — that gap needs fixing in the GeneticStudio project itself, and is now simpler to fix since `PopulationGenetics` is just another product of the one package it already depends on.
  - **`GenotypeMatrixStore` was renamed to `ProjectStore` on 2026-07-25** (breaking — GeneticStudio's build will fail on the old name) as part of making genetic data one of five equal, independently optional components (`StoreComponents`: `.geneticData`, `.graph`, `.results`, `.log`, `.matrices`) instead of a mandatory one, motivated by GeneticStudio's own document-save path (`create(overwrite:true)` + `write` only) silently discarding any graph/results/log data on every save. Migration for GeneticStudio's document/save code specifically:
    - `write(matrix:...)` → `writeGeneticData(matrix:parentage:strata:)`; `projectName`/`species`/`description` moved from that call to `create(at:overwrite:components:projectName:species:description:)`.
    - Replace any `create(at:overwrite:true)` + `write` document-save pattern with `openOrCreate(at:components:projectName:...)` held open across the document session — `writeGeneticData`/`writeGraph` are now replace-in-place (were insert-only before), so re-saving no longer requires destroying the file.
    - `readMatrix()` → `readGeneticData()`.
    - `DatasetSummary`'s `individualCount`/`locusCount`/`markerComposition`/`hasParentage`/`hasGraph`/`hasResults`/`hasLog` are now optional (`nil` = component not present in the file at all, vs. `false`/`0` = present but empty) — plus a new `hasMatrices`.
    - New: `addMatrix(_:name:description:)`/`matrices()`/`matrixData(named:)` for attaching named generic `Matrix` objects (e.g. a derived Fst distance matrix) — works in `Data` (encode/decode via `Matrix`'s existing `Codable` conformance), not a live `Matrix`, since `Matrix` isn't `Sendable`.
    - New `PersistenceError.componentNotPresent(String)` case when reading/writing a component a file wasn't created with.
    - See `Sources/PopulationGenetics/Persistence/ProjectStore.swift` and its `ProjectStore+*.swift` extensions for the full API; `PopGenStore+Persistence.swift` is a worked reference migration.
