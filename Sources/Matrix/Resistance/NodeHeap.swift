//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  NodeHeap.swift
//  Matrix
//
//  A binary min-heap of (node, cost) pairs for Dijkstra's algorithm. Stale
//  entries are left in and skipped when popped, which is simpler than
//  decreasing keys and just as fast on grid graphs.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A min-heap of nodes keyed by cost.
struct NodeHeap {
    private var entries: [(node: Int, cost: Double)] = []

    /// Adds a node.
    mutating func push(node: Int, cost: Double) {
        entries.append((node, cost))
        var child = entries.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard entries[child].cost < entries[parent].cost else { break }
            entries.swapAt(child, parent)
            child = parent
        }
    }

    /// Removes and returns the cheapest node, or `nil` if the heap is empty.
    mutating func pop() -> (node: Int, cost: Double)? {
        guard let top = entries.first else { return nil }
        let last = entries.removeLast()
        guard !entries.isEmpty else { return top }
        entries[0] = last
        var parent = 0
        while true {
            let left = 2 * parent + 1
            let right = left + 1
            var smallest = parent
            if left < entries.count, entries[left].cost < entries[smallest].cost { smallest = left }
            if right < entries.count, entries[right].cost < entries[smallest].cost { smallest = right }
            guard smallest != parent else { return top }
            entries.swapAt(parent, smallest)
            parent = smallest
        }
    }
}
