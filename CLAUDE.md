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
  Matrix/          — Matrices/, Vectors/, Algorithms/, Protocols/, Types/, Operators.swift
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
