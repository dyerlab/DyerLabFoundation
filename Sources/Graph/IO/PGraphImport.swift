//
//  PGraphImport.swift
//  DyerlabFoundation
//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import SwiftUI

extension Graph {

    /// A small, deterministic color palette for formats (like `.pgraph`) that
    /// carry a categorical grouping but no explicit color: the first distinct
    /// group seen is colored `pgraphPalette[0]`, the second `pgraphPalette[1]`,
    /// and so on, cycling once there are more groups than colors.
    static let pgraphPalette: [Color] = [.red, .blue, .green, .orange, .purple, .teal, .pink, .yellow]

    /// Parses the `.pgraph` population-graph text format.
    ///
    /// Format: a header line `<nodeCount> <edgeCount>`, followed by
    /// `nodeCount` node lines of `<name> <size> <group>`, followed by
    /// `edgeCount` edge lines of `<from> <to> <weight>` — all whitespace
    /// (space or tab) separated. Edges are undirected: each is added to the
    /// graph symmetrically. The `group` column is preserved on each node as
    /// a `"group"` categorical attribute; since the format carries no color,
    /// nodes are colorized deterministically by `pgraphPalette`, keyed by
    /// first appearance of each distinct group value.
    ///
    /// - Parameter text: The raw `.pgraph` file contents.
    /// - Returns: The parsed graph.
    public static func importPGraph(text: String) throws -> Graph {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }

        guard let headerLine = lines.first else { throw GraphImportError.malformedHeader }
        let headerFields = headerLine.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard headerFields.count == 2,
              let nodeCount = Int(headerFields[0]),
              let edgeCount = Int(headerFields[1]) else {
            throw GraphImportError.malformedHeader
        }

        let bodyLineCount = lines.count - 1
        guard bodyLineCount >= nodeCount + edgeCount else {
            throw GraphImportError.truncatedFile(expected: nodeCount + edgeCount, found: bodyLineCount)
        }

        let graph = Graph()
        var colorByGroup: [String: Color] = [:]

        for i in 0..<nodeCount {
            let lineNumber = i + 2 // 1-based; line 1 is the header
            let fields = lines[1 + i].split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 3, let size = Double(fields[1]) else {
                throw GraphImportError.malformedNodeLine(lineNumber)
            }
            let name = String(fields[0])
            let group = String(fields[2])
            let color = colorByGroup[group] ?? {
                let assigned = pgraphPalette[colorByGroup.count % pgraphPalette.count]
                colorByGroup[group] = assigned
                return assigned
            }()
            graph.addNode(name: name, size: size, color: color, categoricalAttributes: ["group": group])
        }

        for i in 0..<edgeCount {
            let lineNumber = nodeCount + i + 2
            let fields = lines[1 + nodeCount + i].split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 3, let weight = Double(fields[2]) else {
                throw GraphImportError.malformedEdgeLine(lineNumber)
            }
            let fromName = String(fields[0])
            let toName = String(fields[1])
            guard graph.node(name: fromName) != nil else {
                throw GraphImportError.unknownNode(name: fromName, line: lineNumber)
            }
            guard graph.node(name: toName) != nil else {
                throw GraphImportError.unknownNode(name: toName, line: lineNumber)
            }
            graph.addEdge(from: fromName, to: toName, weight: weight, symmetric: true)
        }

        return graph
    }

    /// Parses a `.pgraph` file at the given URL. See ``importPGraph(text:)`` for the format.
    public static func importPGraph(contentsOf url: URL) throws -> Graph {
        try importPGraph(text: try String(contentsOf: url, encoding: .utf8))
    }
}
