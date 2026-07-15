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
