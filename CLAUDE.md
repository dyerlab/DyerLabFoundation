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

DyerLabFoundation is a **foundation-tier Swift package** consolidating `MatrixStuff` and `PresentationZen` into a single repo. It exposes three library products plus an umbrella:

| Product | Depends on | Purpose |
|---|---|---|
| `Matrix` | — | Linear algebra: matrices, vectors, operators, t-SNE, PCA, `rSourceConvertible` protocol |
| `Graph` | `Matrix` | Generic graph theory: Graph, Node, Edge, Adjacency, Centrality, Path + full force-directed layout engine |
| `PresentationZen` | `Matrix`, `Graph` | Charts, analyses, data-communication helpers, all SwiftUI views (Matrix views, Graph views, charts) |
| `DyerLabFoundation` | all three | Umbrella — re-exports everything via `@_exported import` |

### PresentationZen is the UI layer for everything

All SwiftUI views live in PresentationZen regardless of the type they display. If you need a view for a `Matrix`, `Vector`, or `Graph`, import `PresentationZen`. This means `PresentationZen` depends on both `Matrix` and `Graph`.

### Source layout

```
Sources/
  Matrix/          — Matrices/, Vectors/, Algorithms/, Protocols/, Types/, Operators.swift
  Graph/           — Graphs/{Adjacency,Centrality,Edge,Graph,Node,Path}.swift
                     Graphs/Layout/{Camera,Core,Legacy,Simulation}/
  PresentationZen/ — Analyses/, Charts/, Extensions/, Models/, Protocols/, Tables/, Views/
                     MatrixViews/    ← Matrix + Vector SwiftUI views
                     GraphViews/     ← Graph layout views (GraphLayoutView, MapView, etc.)
  DyerlabFoundation/ — DyerlabFoundation.swift (@_exported imports)
Tests/
  MatrixTests/          GraphTests/          PresentationZenTests/
  DyerlabFoundationTests/
```

### What belongs here vs. what does not

This is a **horizontal foundation** reused across unrelated domains. Domain-specific code must NOT enter this package. The following were intentionally excluded (hand them to the Genetics package):

- `Graphs/PopulationNode.swift`
- `Graphs/MigrationEdge.swift`
- `Views/PopulationGraphView.swift`
- `MatrixAlgebra.swift` genetics section: `CentroidDistance`, `CentroidVariance`, `PopGraph`

### Swift version & platforms

Swift 6 strict concurrency (`swiftLanguageModes: [.v6]`) with `.enableUpcomingFeature("ApproachableConcurrency")` on all targets. Platforms: `.iOS(.v17), .macOS(.v14)`.

### `#Preview` guards

All `#Preview` macros are wrapped in `#if !SPM_BUILD` / `#endif`. The `SPM_BUILD` flag is defined on every target for command-line builds, suppressing previews that require Xcode's `PreviewsMacros` plugin.

### SwiftData note

`PresentationZen/Models/Media.swift` uses SwiftData's `@Model` macro. This macro plugin is only resolved by Xcode's build system — build `PresentationZen` from Xcode. `Matrix` and `Graph` build and test cleanly from the command line.

### Design document

`DyerLabFoundation-Consolidation.md` in the repo root is the original design brief — read it before making structural changes to targets or the Package.swift manifest.

### Downstream consumers

- **PopulationGenetics** — will switch from `import MatrixStuff` to `import Matrix` / `import Graph` in `Extensions/Array+Node.swift` and `Simulation/Migration.swift`.
- **Linguistics** — uses `Matrix` + `PresentationZen`; migration deferred.
