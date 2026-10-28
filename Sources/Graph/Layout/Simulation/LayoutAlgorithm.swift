//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  LayoutAlgorithm.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.06.22.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A graph layout algorithm ``LayoutOrchestrator`` can run.
public enum LayoutAlgorithm: String, CaseIterable, Identifiable, Sendable {
    /// Force-directed: springs along edges, repulsion between every pair,
    /// annealed by a cooling schedule.
    case fruchtermanReingold

    /// Stress layout: springs between every pair, sized to their
    /// shortest-path distance (see ``KamadaKawaiSolver``). Tends to spread
    /// clusters further apart, and matches R's `igraph::layout_with_kk()`.
    case kamadaKawai

    public var id: Self { self }

    /// Human-readable name for pickers.
    public var displayName: String {
        switch self {
        case .fruchtermanReingold: "Fruchterman–Reingold"
        case .kamadaKawai: "Kamada–Kawai"
        }
    }
}
