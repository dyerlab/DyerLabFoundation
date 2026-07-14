//
//  DyerlabFoundation.swift
//  DyerLabFoundation
//
//  Umbrella module — re-exports Matrix, Graph, PresentationZen, and
//  PopulationGenetics. Consumers that only want the horizontal, domain-
//  agnostic layer should depend on the individual products (Matrix/Graph/
//  PresentationZen) directly rather than this umbrella — Linguistics does
//  exactly that, so re-exporting PopulationGenetics here has no effect on
//  it: SPM's per-product dependency graph, not this file, is what keeps
//  domain-specific code out of consumers that don't ask for it.
//

@_exported import Matrix
@_exported import Graph
@_exported import PresentationZen
@_exported import PopulationGenetics
