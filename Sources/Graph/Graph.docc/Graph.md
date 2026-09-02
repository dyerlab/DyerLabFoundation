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
- ``RandomizeGraph(graph:mode:seed:)`` — a `.full` or degree-preserving edge randomisation (`randomize_graph()`).
- ``AsymmetryBandwidthTest(graph:permutations:seed:)`` / ``AsymmetryNetworkTest(graph:permutations:rewire:seed:)`` / ``AsymmetrySignificance(graph:mode:permutations:rewire:pendants:seed:)`` — the graph-only resampling nulls for edge asymmetry (`asymmetry_bandwidth()` / `asymmetry_network()` / `asymmetry_significance()`). Seeded via ``RMersenneTwister``, so output is bit-identical to R's `set.seed(seed); …`.

### Force-directed layout

- ``LayoutConfiguration`` — configures the force-directed simulation.
- ``LayoutOrchestrator`` / ``LayoutState`` — drives the simulation loop and holds its running state.
- ``SettleDetector`` — detects when a layout simulation has converged.
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
