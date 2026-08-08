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

### Force-directed layout

- ``ForceDirectedLayout`` / ``LayoutConfiguration`` — configures and runs the force-directed simulation.
- ``LayoutSimulation`` / ``LayoutOrchestrator`` / ``LayoutState`` — drives the simulation loop and holds its running state.
- ``SettleDetector`` — detects when a layout simulation has converged.
- ``EdgeState`` / ``EdgeStateManager`` — per-edge animation/visual state during layout.
- ``Camera2D`` — a 2D viewport/camera for rendering a laid-out graph.
- ``LayoutUpdateCallback`` — the callback shape a host view uses to observe layout progress.

### Views

`Graph` owns its own SwiftUI views rather than relying on `PresentationZen` — a graph's rendering is
inseparable from the layout engine that drives it.

- ``GraphLayoutView`` — a thin composition root: renders a graph using the force-directed layout engine, with pan/zoom, node dragging, and controls.
- ``GraphCanvasView`` — the `Canvas`-based rendering + pan/zoom/drag-gesture surface, independently previewable.
- ``GraphControlPanel`` / ``GraphInspectorPanel`` — the stats/play/pause/reset/reheat bar and the rendering/physics-slider sidebar, also independently previewable.
- ``GraphLayoutOptions`` — the display/chrome options (labels, inspector/controls visibility, edge width, node size) shared across the three views above.
- ``LayoutAnimator`` — an `@Observable` SwiftUI bridge that drives a layout simulation's animation loop.
- ``MapView`` — a MapKit-backed spatial view for graphs whose nodes carry geographic coordinates.

### File import

- ``Graph/importPGraph(text:)`` / ``Graph/importPGraph(contentsOf:)`` — parses the `.pgraph` population-graph text format.
- ``Graph/importGeoJSON(data:)`` / ``Graph/importGeoJSON(contentsOf:)`` — parses a GeoJSON `FeatureCollection` (`Point` nodes, `LineString` edges).
- ``GraphImportError`` — errors thrown by both importers.
- ``GraphExampleData`` — locates this package's bundled example graph files (see `Data/`).
