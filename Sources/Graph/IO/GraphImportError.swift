//
//  GraphImportError.swift
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

/// Errors thrown by `Graph`'s file importers (`.pgraph`, GeoJSON).
public enum GraphImportError: LocalizedError, Equatable {

    /// The `.pgraph` header line isn't two whitespace-separated integers.
    case malformedHeader

    /// The file has fewer node/edge lines than its header declared.
    case truncatedFile(expected: Int, found: Int)

    /// A `.pgraph` node line isn't `<name> <size> <group>`.
    case malformedNodeLine(Int)

    /// A `.pgraph` edge line isn't `<from> <to> <weight>`.
    case malformedEdgeLine(Int)

    /// An edge referenced a node name not declared in the node section.
    case unknownNode(name: String, line: Int)

    /// The GeoJSON top-level object isn't a `FeatureCollection`, or a
    /// feature's geometry/properties don't match the expected shape.
    case invalidGeoJSON(String)

    /// A GeoJSON `Point` feature has no `name` property.
    case missingNodeName

    /// A GeoJSON `LineString` feature's endpoint doesn't match any `Point`'s coordinates.
    case unresolvedEdgeEndpoint

    public var errorDescription: String? {
        switch self {
        case .malformedHeader:
            return "The .pgraph header line must be '<nodeCount> <edgeCount>'."
        case .truncatedFile(let expected, let found):
            return "Expected \(expected) node/edge lines but the file only has \(found)."
        case .malformedNodeLine(let line):
            return "Line \(line) is not a valid node line ('<name> <size> <group>')."
        case .malformedEdgeLine(let line):
            return "Line \(line) is not a valid edge line ('<from> <to> <weight>')."
        case .unknownNode(let name, let line):
            return "Line \(line) references node '\(name)', which was not declared."
        case .invalidGeoJSON(let reason):
            return "Invalid GeoJSON: \(reason)"
        case .missingNodeName:
            return "A GeoJSON Point feature is missing its 'name' property."
        case .unresolvedEdgeEndpoint:
            return "A GeoJSON LineString feature's coordinates don't match any Point feature."
        }
    }
}
