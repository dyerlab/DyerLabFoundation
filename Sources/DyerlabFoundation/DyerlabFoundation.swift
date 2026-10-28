//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DyerlabFoundation.swift
//  DyerlabFoundation
//
//  Umbrella module — re-exports Matrix, Graph, PresentationZen, and
//  PopulationGenetics. Consumers that only want the horizontal, domain-
//  agnostic layer should depend on the individual products (Matrix/Graph/
//  PresentationZen) directly rather than this umbrella — Linguistics does
//  exactly that, so re-exporting PopulationGenetics here has no effect on
//  it: SPM's per-product dependency graph, not this file, is what keeps
//  domain-specific code out of consumers that don't ask for it.
//
//  Created by Rodney Dyer on 2026.06.22.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

@_exported import Matrix
@_exported import Graph
@_exported import PresentationZen
@_exported import PopulationGenetics
