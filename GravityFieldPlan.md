# Plan: Gravity-field visualisation (`plot(gravity_field(graph))` in Swift)

Status as of 2026-10-07: **planned, not started.** Branch `feature/gstudio-1.15-sync` holds the finished,
uncommitted gstudio 1.15 sync and genetic-gravity ports. The user does all commits.

## Goal

Swift version of gstudio's `gravity_field()` and `plot.gravity_field()`:
- **R sources:** `~/Coding/gstudio/R/gravity_field.R`, `R/plot_gravity_field.R`, and the layout helper
  `.graph_layout()` in `R/plot_popgraph.R`.
- **What the plot shows:**
  - an interpolated surface of the source-sink score S (blue = sink, white = 0, red = source) with contour lines;
  - the graph's edges;
  - a source→sink arrow at each edge midpoint, with length proportional to |Δ|;
  - the nodes.
- **Panels:** a field with several panels draws as side-by-side facets on a **common** colour scale and arrow scale.

The work splits into three layers, the same way R splits it. Only layer 3 involves SwiftUI.

**Open decision.** The renderer for layer 3 is either:
- **(a)** a 2D `Canvas` view that reproduces R's figure, with a RealityKit 3D view later; or
- **(b)** RealityKit first, consistent with the RealityKit-unification decision.

My recommendation is (a). The user has not chosen yet, so **confirm before starting layer 3.** Layers 1 and 2 are
needed either way, so they can go ahead now.

---

## Layer 1: the `GravityField` data model

- **File:** new `Sources/Graph/Extensions/GravityField.swift`. Domain-neutral, no UI.
- **Builds on** existing code in `GeneticGravity.swift`: `SourceSinkScores(graph:gamma:x:)`,
  `GravityEdges(graph:gamma:x:)` and `PartitionedGeneticDistanceGraph(graph:gamma:)`.

Types:
- **`GravityFieldNode`:** `panel`, `stratum`, `degree`, `size`, `s`, `gravity`.
  - `size` is the node's size attribute if it has one, otherwise its degree. In Swift every `Node` has `size`, so
    keep a flag saying whether that size was meaningful; R marks the fallback as NA when plotting.
- **`GravityFieldEdge`:** `panel`, `from`, `to`, `weight`, `delta`, `source`, `sink`.
  - When `delta >= 0`, `source = from` and `sink = to`; otherwise they swap.
- **`GravityFieldDiagnostics`:** `panel`, `gamma`, `degreeShare`, `corSDegree`, `corSS0`, `gradientShare`.
- **`GravityField`:** a list of panels, each holding its graph, nodes, edges and diagnostics.

Constructors and helpers:
- **`GravityField(graph:gamma:)`.** One graph with one γ gives a single panel named `""`. One graph with several γ
  values gives one panel per γ, named `"gamma = %g"`.
- **`GravityField(graphs: [(name, Graph)], gamma: [Double])`.**
  - γ is recycled over the panels.
  - Blank names become `"Graph i"` when there is more than one panel.
  - Duplicate names are made unique R-style (`make.unique(sep = " ")`).
- **A `combine` function**, the equivalent of R's `c.gravity_field`. A named argument prefixes the existing panel
  names; for a field with several panels the result is `"name: panel"`. Duplicate panel names are an error.
- **Text summary**, the equivalent of `print.gravity_field`. Per panel it gives γ, the degree share, cor(S, k), the
  gradient share, and the top n sources and sinks.

**Tests:** `Tests/GraphTests/GravityFieldTests.swift`, at 1e-10 against R, with fixtures added to
`Tests/GraphTests/Fixtures/generate_gravity_fixtures.R`. Cases:
- a single panel;
- one graph at γ = c(1, 0.5);
- several panels via `c()`.

---

## Layer 2: plot geometry (pure functions that can be tested against R)

**Generic algorithms go in Matrix/Algorithms. They are domain-neutral and reusable:**
- `KernelInterpolation.swift`: Gaussian-kernel interpolation onto a grid.
  - Each cell's value is `Σ wᵢ Sᵢ / max(Σ wᵢ, 1e-9)` with `wᵢ = exp(−½ (d/h)²)`.
  - A nearest-node ("voronoi") variant.
- `MarchingSquares.swift`: contour lines from a grid with NaN masking.
  - The contour levels must be the levels ggplot uses for `geom_contour(bins = 10)`. Check how ggplot computes its
    breaks before writing this.

**Gravity-specific geometry goes in Graph, as `GravityFieldGeometry.swift`.** Port from `plot.gravity_field`:
- **Layout resolution**, the equivalent of `.graph_layout()`. Order of precedence:
  1. coordinates supplied explicitly, as `[String: CGPoint]` or a two-column Matrix;
  2. `Node.coordinate` (geographic);
  3. if neither exists, the force-directed engine (`LayoutOrchestrator`, run until settled or for a fixed number of
     steps) applied to `PartitionedGeneticDistanceGraph`.

  R falls back to Kamada–Kawai on the pGD graph, so step 3 is functional parity only.
  - Known bug: `bug_settle_detection_never_fires` (in the memory folder). Settle detection never fires on real
    weighted graphs, so step 3 needs an iteration cap.
  - When every panel has the same nodes, one layout (from panel 1) is used for all panels.
- **Mask distance.**
  - `nn` is the median nearest-neighbour distance between nodes, computed from panel 1 only.
  - `nn` is floored at `0.25 · sqrt(bboxArea / n)` and at 1e-9.
  - The mask distance defaults to `1.2 · nn`.
  - The interpolation bandwidth is `h = max(1.2 · nn, 1e-6)`.
- **Grid.** `gridN = 140` points per axis, padded by `0.12 · max(xRange, yRange)`. Cells with `minDist > maskDist`
  become NaN.
- **Colour limit.** `lim = max|S|` over all panels; use 1 if that is 0 or not finite.
- **Arrows.**
  - Drop arrows with |Δ| ≤ 1e-6, then apply the optional `minDelta` quantile filter.
  - Length is `L = arrowScale · |Δ| / max|Δ| · medianEdgeLength`. `max|Δ|` is taken over **all panels**, before
    filtering.
  - Each arrow is centred on its edge midpoint and points along the unit vector from source to sink.
- **Edge segments**, plus the facet labels:
  - each label is the panel name, followed when `subtitle_stats` is on by a second line
    `"degree share %.2f, cor(S, k) %.2f"`;
  - labels are made unique.

**Tests:** these become R-parity tests once the layout is fixed. Export from R, for a fixed `layout = xy`:
- the `surf` grid values;
- the mask;
- the arrow end points `x0, y0, x1, y1`;
- `nn` and `edge_len`.

Use the 12-node example from `plot_gravity_field.R`'s roxygen block (`set.seed(4)`), at both γ values. Contours get
behavioural tests (each closed level line actually separates higher values from lower ones) unless ggplot's breaks
can be reproduced exactly.

---

## Layer 3: rendering (pending the (a)/(b) decision)

### (a) 2D: `Sources/Graph/Views/GravityFieldView.swift`

Graph owns its views (CLAUDE.md). It uses SwiftUI `Canvas`, not Swift Charts: about 20,000 raster marks would be
slow, and Swift Charts has no contours.

- **Surface:** turn the grid into a `CGImage` via a diverging colour ramp.
  - Default palette `#2166ac` / `#f7f7f7` / `#b2182b`; NaN cells are transparent.
  - Draw it with interpolation on, to match R's `geom_raster(interpolate = TRUE)`.
- **Drawing order:** surface, then contours (grey35, 0.25 pt), then edges, then arrows (black, closed heads), then
  nodes with labels.
- **Node and edge styling:** match `GraphCanvasView`.
- **Options struct**, mirroring the R arguments:
  - `nodeSize` (size / degree / constant)
  - `nodeLabels` (name / degree / size / none)
  - `nodeFill`
  - `showEdges`
  - `edgeWidth` (constant / weight)
  - `surface` (interpolate / voronoi / none)
  - `arrows`
  - `palette`
  - `subtitleStats`
  - `maskDistance`
  - `arrowScale`
  - `minDelta`
  - `gridN`
- **Facets:** use a grid of panels with a shared colour-bar legend titled "Source–sink score S (red = source,
  blue = sink)".
- **Interaction:** pan and zoom via `Camera2D` if cheap; otherwise static.
- **Export:** a PNG/PDF helper built on `ImageRenderer`.
- **Previews:** `#Preview` using the 12-node example and gstudio's `gravity` graph. Keep view bodies shallow (see the
  feedback memory): extract the drawing into helper functions or small subviews.

### (b) RealityKit 3D, later or instead

- **Mesh:** a height mesh from the same grid. Height = S, so sources are peaks and sinks are valleys.
  - Colour each vertex from the same ramp.
  - Leave out masked cells.
- **On top of the mesh:** arrows as small cones along the edges, and nodes as spheres at height S.
- **Code:** reuse `RealityGraphEntityBuilder` patterns.

### Later: map version

For graphs with coordinates. SwiftUI `Map` has no image overlay, so draw filled contour bands as `MapPolygon`s, plus
`MapPolyline` edges and arrow annotations.

---

## Docs and housekeeping when done

- `Graph.docc/Graph.md`: add the gravity-field model and view. Matrix's `.md` gets the interpolation and
  marching-squares entries.
- `CLAUDE.md`: in the source-layout notes, replace "gravity_field()/plotting are R-only" with the new mapping.
- **Fixtures:** extend `generate_gravity_fixtures.R`. Write any NA as `na = "null"` and omit NULL elements; jsonlite
  turns NULL into `{}`.
- **Build and test:** `env DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test`. Run the full
  suite at the end.
- **Do not commit.** The user handles commits.

## Suggested order

1. Layer 1 and its tests.
2. Layer 2: generic algorithms, then gravity geometry, then R fixtures and parity tests.
3. Confirm (a) or (b), then layer 3 with previews.
4. Docs and CLAUDE.md.
