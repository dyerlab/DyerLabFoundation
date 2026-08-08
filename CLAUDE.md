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

All SwiftUI views for `Matrix`/`Vector` (plus general data-communication views: charts, tables, analyses) live in PresentationZen — import `PresentationZen` for those. `Graph` is a deliberate exception (as of 2026-08-08): its views (`GraphLayoutView`, `MapView`, `NodeInspectorForm`, `LayoutAnimator`, under `Sources/Graph/Views/`) live alongside its model and force-directed layout engine rather than in PresentationZen, because a graph's rendering is inseparable from the layout-simulation state that drives it. `PresentationZen` still depends on both `Matrix` and `Graph` (for the layout engine and non-view types it re-uses), but no longer supplies Graph's SwiftUI views — code that imported `PresentationZen` only to reach `GraphLayoutView`/`MapView` must now `import Graph` instead.

### Source layout

```
Sources/
  Matrix/          — Matrices/, Vectors/, Algorithms/, Protocols/, Types/, Operators.swift
  Graph/           — Models/{Graph,Node,Edge,Path}.swift, Extensions/{Adjacency,Centrality}.swift
                     Layout/{Camera,Core,Legacy,Simulation}/
                     Views/  ← GraphLayoutView (composition root), GraphCanvasView, GraphControlPanel,
                               GraphInspectorPanel, GraphLayoutOptions, MapView, NodeInspectorForm, LayoutAnimator
                     IO/     ← file import: importPGraph, importGeoJSON, GraphExampleData
                     Data/   ← bundled example graph files (lopho.pgraph, lopho.geojson)
  PresentationZen/ — Analyses/, Charts/, Extensions/, Models/, Protocols/, Tables/, Views/
                     MatrixViews/    ← Matrix + Vector SwiftUI views
  PopulationGenetics/ — Genetic/, DataStore/, Persistence/, Simulation/, PopulationGraph/,
                     Algorithms/, Models/, Protocols/, Types/, Extensions/, Views/, ExampleData/
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

Swift 6 strict concurrency (`swiftLanguageModes: [.v6]`) with `.enableUpcomingFeature("ApproachableConcurrency")` on all targets. Platforms: `.iOS(.v17), .macOS(.v14)`.

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

A pre-existing, unrelated issue surfaced during that verification: six DocC symbol-link warnings in
`PresentationZen/Analyses/{anovaTable,RegressionResult,DateRegression,hypergeometricScenarios}.swift`'s doc
comments (references to `LinearModelFit`/`PermutationTestResult`/`hypergeometricProbability` that don't resolve).
Not touched as of 2026-07-15 — flagged for a future pass.

### Design document

`DyerLabFoundation-Consolidation.md` in the repo root is the original design brief — read it before making structural changes to targets or the Package.swift manifest.

### Downstream consumers

- **PopulationGenetics** — no longer a separate downstream consumer; folded into this repo as of 2026-07-14 (see above). The standalone `github.com/dyerlab/PopulationGenetics` repo is legacy.
- **Linguistics** — uses `Matrix` + `PresentationZen`; resolves `dyerlabfoundation` off `branch: "main"`, not a version tag. Migration to consume newer foundation APIs deferred, but a broken `main` here breaks this too — land nontrivial foundation changes on a feature branch and verify against real downstream consumers before merging.
- **GeneticStudio** — a new app being built directly against this foundation as it evolves; not a stability concern, expected to simply conform. Its Xcode project currently only references the `dyerlabfoundation` package (no separate `PopulationGenetics` dependency), even though its own source already calls PopulationGenetics-only types (`ImportedDataset`, `ProjectStore`, `importMicrosatTable`) — that gap needs fixing in the GeneticStudio project itself, and is now simpler to fix since `PopulationGenetics` is just another product of the one package it already depends on.
  - **`GenotypeMatrixStore` was renamed to `ProjectStore` on 2026-07-25** (breaking — GeneticStudio's build will fail on the old name) as part of making genetic data one of five equal, independently optional components (`StoreComponents`: `.geneticData`, `.graph`, `.results`, `.log`, `.matrices`) instead of a mandatory one, motivated by GeneticStudio's own document-save path (`create(overwrite:true)` + `write` only) silently discarding any graph/results/log data on every save. Migration for GeneticStudio's document/save code specifically:
    - `write(matrix:...)` → `writeGeneticData(matrix:parentage:strata:)`; `projectName`/`species`/`description` moved from that call to `create(at:overwrite:components:projectName:species:description:)`.
    - Replace any `create(at:overwrite:true)` + `write` document-save pattern with `openOrCreate(at:components:projectName:...)` held open across the document session — `writeGeneticData`/`writeGraph` are now replace-in-place (were insert-only before), so re-saving no longer requires destroying the file.
    - `readMatrix()` → `readGeneticData()`.
    - `DatasetSummary`'s `individualCount`/`locusCount`/`markerComposition`/`hasParentage`/`hasGraph`/`hasResults`/`hasLog` are now optional (`nil` = component not present in the file at all, vs. `false`/`0` = present but empty) — plus a new `hasMatrices`.
    - New: `addMatrix(_:name:description:)`/`matrices()`/`matrixData(named:)` for attaching named generic `Matrix` objects (e.g. a derived Fst distance matrix) — works in `Data` (encode/decode via `Matrix`'s existing `Codable` conformance), not a live `Matrix`, since `Matrix` isn't `Sendable`.
    - New `PersistenceError.componentNotPresent(String)` case when reading/writing a component a file wasn't created with.
    - See `Sources/PopulationGenetics/Persistence/ProjectStore.swift` and its `ProjectStore+*.swift` extensions for the full API; `PopGenStore+Persistence.swift` is a worked reference migration.
