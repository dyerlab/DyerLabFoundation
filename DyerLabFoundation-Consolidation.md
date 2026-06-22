# DyerLabFoundation — Consolidation Brief

**For:** a separate agent tasked with creating a new `DyerLabFoundation` Swift package.
**Goal:** merge the two existing standalone packages **MatrixStuff** and **PresentationZen**
into one repo/package exposing three library targets — **Matrix**, **Graph**, **PresentationZen**
— plus an umbrella `DyerLabFoundation` product. This becomes the shared *foundation tier*
reused by multiple unrelated domains (PopulationGenetics, Linguistics, …).

> **Git:** Rodney performs git operations himself. Treat the repo-creation / history-import
> steps below as a checklist for him to run (or to run only with his go-ahead), not something
> to execute unprompted.

---

## 1. Why this exists (design rationale)

`MatrixStuff` (linear algebra + graph theory) and `PresentationZen` (charting / data-comm / UI)
are **horizontal foundation** libraries used by *multiple unrelated domains*. They must live in
their own tier — NOT folded into any one domain package — so that, e.g., the Linguistics package
doesn't transitively drag in genetics code and vice-versa. Consolidating the two foundation repos
into one package (with targets) removes the cross-repo "edit upstream → tag/bump/resolve" friction
while keeping the foundation cleanly separable from the domains above it.

Consumers pick only the products they link; targets in one package see each other's changes
instantly (no version resolution), and cross-cutting refactors are atomic.

---

## 2. Target layout & dependency DAG

```
Matrix            (linear algebra: matrices, vectors, operators, R-source protocol)
   ▲
Graph             (generic graph theory: Graph, Node, Edge, Adjacency, Centrality, Path)
                  depends on Matrix (adjacency → Matrix)

PresentationZen   (charting / data-communication / general UI)
                  depends on Matrix only if its charts consume Matrix/Vector — verify from imports

DyerLabFoundation (umbrella product; re-exports Matrix + Graph + PresentationZen)
```

- Each library target gets its own test target (`MatrixTests`, `GraphTests`, `PresentationZenTests`),
  migrating the corresponding existing tests.
- The umbrella target may use `@_exported import Matrix` / `Graph` / `PresentationZen` so a consumer
  can `import DyerLabFoundation` and get everything, or import the three individually.

---

## 3. File mapping — MatrixStuff → targets

MatrixStuff's known layout is `Sources/MatrixStuff/…`. Map as follows:

**→ `Matrix` target**
- `Matrices/*` (Matrix, MatrixAlgebra, MatrixConvertable, MatrixMatrixOperations, MatrixScalarOperators)
- `Vectors/*` (Vector, VectorConvertable, VectorScalarOperators, VectorVectorOperators, Random, RangeEnum)
- `Operators.swift`
- `Protocols/rSourceConvertible.swift` (generic R-source emission; foundation-level)
- Fold/remove the old `MatrixStuff.swift` umbrella doc file.

**→ `Graph` target** (depends on `Matrix`)
- `Graphs/Graph.swift`, `Graphs/Node.swift`, `Graphs/Edge.swift`,
  `Graphs/Adjacency.swift`, `Graphs/Centrality.swift`, `Graphs/Path.swift`

**⚠️ DO NOT include in foundation — these are population-genetics domain code; hand them to the
Genetics package instead (leave them out of DyerLabFoundation and list them in the hand-off
inventory, §6):**
- `Graphs/PopulationNode.swift`
- `Graphs/MigrationEdge.swift`
- `Views/PopulationGraphView.swift`

**MatrixStuff `Views/` — judgement call (inspect each):**
- `Views/MapView.swift`, `Views/NodeInspectorForm.swift` — if genuinely generic (a reusable map /
  a generic node inspector), they may go to `PresentationZen` (or a small `GraphUI`). If either is
  genetics-specific, exclude it like `PopulationGraphView`. Decide from their actual contents/imports.

---

## 4. PresentationZen → `PresentationZen` target

PresentationZen's internal structure is not documented here — **inspect the repo and bring its
general-purpose components** (charts, data-communication helpers, reusable UI). Apply the same
test as above: **anything domain-specific (genetics, linguistics, etc.) must NOT enter the
foundation** — flag it for the relevant domain package instead. Determine PresentationZen's own
external dependencies from its `Package.swift`/imports and carry them into the new manifest.

---

## 5. Package.swift requirements

- `swift-tools-version` ≥ 6.1 (match the higher of the two source packages; Swift 6 strict concurrency).
- Platforms: take the **union of the most permissive** that still compiles across both sources
  (MatrixStuff/PopulationGenetics use `.iOS(.v17), .macOS(.v14)` — start there; widen only if a
  source package already requires older). Apple-only is fine (CoreLocation/SwiftUI permitted).
- Products: `.library` for each of `Matrix`, `Graph`, `PresentationZen`, and `DyerLabFoundation` (umbrella).
- Targets + matching test targets; wire `Graph` → `Matrix` dependency; PresentationZen deps per its imports.
- Carry over any external dependencies PresentationZen/MatrixStuff declared.

---

## 6. Deliverables back to the caller

1. The new `DyerLabFoundation` package, building clean (`swift build`) with all migrated tests passing.
2. **Hand-off inventory** — a short list of the genetics-domain files intentionally **excluded**
   from foundation (`PopulationNode`, `MigrationEdge`, `PopulationGraphView`, plus any domain views
   found in PresentationZen), so they can be re-homed in the Genetics package.
3. **Downstream import-migration note** — the renames consumers must make. Known so far:
   - **PopulationGenetics** depends on `MatrixStuff` in `Sources/PopulationGenetics/Extensions/Array+Node.swift`
     (`Matrix`, `Node`) and `Sources/PopulationGenetics/Simulation/Migration.swift` (`Matrix`). After
     consolidation these become `import Matrix` / `import Graph` and a dependency on the
     `DyerLabFoundation` package's `Matrix` + `Graph` products. PopulationGenetics does **not** use
     PresentationZen.
   - Linguistics uses `MatrixStuff` + `PresentationZen` (+ someAI) — to be migrated later by Rodney.

---

## 7. History preservation (for Rodney's git step)

To keep each source repo's history under the new layout:

```
# in the new empty DyerLabFoundation repo
git subtree add --prefix=Sources/_import_matrixstuff   <matrixstuff-remote>   main
git subtree add --prefix=Sources/_import_presentationzen <presentationzen-remote> main
# then move files into Sources/Matrix, Sources/Graph, Sources/PresentationZen per §3–§4,
# delete the _import_* staging dirs and the old Package.swift files, and write the new manifest.
```

Validate with `swift build` and the full test suite before tagging.
