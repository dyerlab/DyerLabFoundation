# ``Graph``

Generic graph theory and a full force-directed layout engine, built on `Matrix`.

## Overview

`Graph` provides a generic graph data structure plus everything needed to lay one out spatially — from adjacency
and centrality measures to a real-time force-directed simulation. It has no notion of what a graph's nodes or
edges *mean*; `PopulationGenetics` uses it for population graphs, and any other domain-specific package can use
it the same way.

### Core graph structure

- ``Graph`` — the graph itself: nodes, edges, and their relationships, with adjacency and centrality measures.
- ``Node`` / ``Edge`` — the graph's vertices and connections.
- ``Path`` — a path through the graph.

### Population-graph analysis

Ports of gstudio's downstream `popgraph` operations, numerically identical to the R implementations. Domain-neutral weighted-graph operations — `PopulationGenetics` builds the graphs these consume.

- ``GraphAsymmetries(graph:bandwidth:scale:)`` — directional introgression weights and a per-edge asymmetry index from a local Gaussian kernel (`graph_asymmetries()`).
- ``AsymmetricWeights(graph:perplexity:tolerance:maxIterations:)`` / ``AsymmetricPopulationGraph(graph:perplexity:tolerance:maxIterations:)`` — a t-SNE-style split of each edge's conditional genetic distance into directional shares (`asymmetric_weights()` / `asymmetric_popgraph()`).
- ``CongruenceTopology(_:_:)`` / ``TestCongruence(_:_:)`` — the shared-edge topology of two graphs and a Pearson test between their distance structures (`congruence_topology()` / `test_congruence()`).
- ``Graph/subtractingEdges(in:)`` — one graph's edges with another's removed (`-.popgraph`).
- ``RandomizeGraph(graph:mode:seed:)`` — a `.full` or degree-preserving (edge-swap) randomisation (`randomize_graph()`).
- ``AsymmetryBandwidthTest(graph:permutations:returnNull:seed:)`` / ``AsymmetryNetworkTest(graph:permutations:rewire:returnNull:seed:)`` / ``AsymmetrySignificance(graph:mode:permutations:rewire:pendants:returnNull:seed:)`` — the graph-only resampling nulls for edge asymmetry (`asymmetry_bandwidth()` / `asymmetry_network()` / `asymmetry_significance(mode = "mechanism" | "existence")`). Seeded via `RMersenneTwister`: the bandwidth null and `.full` randomisation are bit-identical to R's `set.seed(seed); …`; `.degree` rewiring is a functional port of igraph's `rewire(keeping_degseq())`, statistically but not draw-for-draw equivalent.

### Genetic gravity

Ports of gstudio's genetic-gravity core (≥ 1.15), one sign convention throughout — higher = more of a source. Bandwidth `bᵢ = γ · sᵢ/kᵢ`: `γ = 0.5` (default) is degree-neutral, for inferring direction; `γ = 1` is the local mean, for describing connectivity; `γ = .infinity` is the flat, degree-only kernel.

- ``NeighbourhoodWeights(graph:gamma:)`` — the neighbourhood-weight matrix `W[i, j] = w_{j|i}` (`neighbourhood_weights()`).
- ``GravityEdges(graph:gamma:x:)`` — per-edge weights, the gravity asymmetry `Δ_{i→j} = w_{i|j} − w_{j|i}` and its degree-only term `Δ⁰` (`gravity_edges()`).
- ``SourceSinkScores(graph:gamma:x:)`` — each population's gravity, source-sink balance and least-squares source-sink score `S`, with the degree diagnostics to report alongside any directional analysis (`source_sink_scores()`).
- ``PartitionedGeneticDistanceGraph(graph:gamma:)`` / ``PartitionedGeneticDistance(graph:gamma:)`` — each edge's conditional genetic distance split into directed shares, as a directed graph or all-pairs directed distance matrix (`pgd()`).
- ``SourceSinkTest(graph:x:gamma:permutations:null:interior:edgeMargin:returnNull:seed:)`` — Spearman `r(S, x)` between source-sink scores and a covariate, against a Moran spectral randomization null on the graph (default), a permutation of `S`, or a supplied adjacency (`source_sink_test()`).
- ``IsolationByGraphDistance(graph:separation:permutations:seed:)`` — cGD against separation with a Mantel permutation test (`ibgd(mode = "cgd")`).
- ``DirectionalIsolationByGraphDistance(graph:separation:gamma:)`` — does directed pGD with forward/reverse slopes fit better than cGD? Reports `ΔR²` and the slope ratio; no p-value (`ibgd(mode = "pgd")`).

### Layout

- ``LayoutAlgorithm`` — Fruchterman–Reingold (force-directed) or Kamada–Kawai (stress), selected via
  ``LayoutConfiguration/algorithm`` or switched live with ``LayoutOrchestrator/setAlgorithm(_:)``.
- ``KamadaKawaiSolver`` / ``KamadaKawaiWeighting`` — a port of igraph's `layout_with_kk()`. It is usable headless
  (`Graph.kamadaKawaiLayout(weighting:initial:maxIterations:)`) or animated by the orchestrator. The default
  weighting matches gstudio's `layout = "kk"`.
- ``LayoutConfiguration`` — selects the algorithm and configures the force-directed simulation.
- ``LayoutOrchestrator`` / ``LayoutState`` — drives the simulation loop and holds its running state.
- ``SettleDetector`` — detects when a layout has stopped visibly moving (largest per-node move per frame below
  ``LayoutConfiguration/settleThreshold``).
- ``SettleOutcome`` / ``MotionTrend`` — whether a run came to rest or was cut off by its budget
  (``LayoutOrchestrator/iterationBudget``) while still moving. In the second case it suggests a larger budget,
  estimated from how fast motion was decaying on that graph; ``LayoutOrchestrator/continueRun(toBudget:)`` follows it.
- ``EdgeState`` / ``EdgeStateManager`` — per-edge animation/visual state during layout.
- ``Camera2D`` — a 2D viewport/camera for rendering a laid-out graph.

### Views

`Graph` owns its own SwiftUI views rather than relying on `PresentationZen` — a graph's rendering is
inseparable from the layout engine that drives it.

- ``GraphLayoutView`` — a thin composition root: renders a graph using the force-directed layout engine, with pan/zoom, node dragging, and controls.
- ``GraphCanvasView`` — the `Canvas`-based rendering + pan/zoom/drag-gesture surface, independently previewable.
- ``GraphControlPanel`` / ``GraphInspectorPanel`` — the stats/play/pause/reset/reheat bar and the rendering/physics-slider sidebar, also independently previewable.
- ``GraphLayoutOptions`` — the display/chrome options (labels, inspector/controls visibility, edge width, node size) shared across the three views above.
- ``MapView`` — a MapKit-backed spatial view for graphs whose nodes carry geographic coordinates.
- ``RealityGraphView`` — a RealityKit-based 3D visualization, on iOS/macOS as a windowed scene and on visionOS as
  a volumetric one; the intended long-term replacement for ``GraphCanvasView`` across all three platforms (see the
  `realitykit_unification_decision` design note). Uses a headless `LayoutOrchestrator` precompute pass, then hands
  live rendering/interaction to RealityKit's own physics via ``RealityGraphEntityBuilder``, configured by
  ``RealityGraphOptions``.

### File import

- ``Graph/importPGraph(text:)`` / ``Graph/importPGraph(contentsOf:)`` — parses the `.pgraph` population-graph text format.
- ``Graph/importGeoJSON(data:)`` / ``Graph/importGeoJSON(contentsOf:)`` — parses a GeoJSON `FeatureCollection` (`Point` nodes, `LineString` edges).
- ``GraphImportError`` — errors thrown by both importers.
- ``GraphExampleData`` — locates this package's bundled example graph files (see `Data/`).
