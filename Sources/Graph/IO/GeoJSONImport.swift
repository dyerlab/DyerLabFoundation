//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GeoJSONImport.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.08.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import SwiftUI
import CoreLocation

extension Graph {

    /// Parses a GeoJSON `FeatureCollection` into a graph.
    ///
    /// `Point` features become nodes: `name` is required, `size`/`color`
    /// properties are used if present (defaulting to `1.0`/`.red`), and any
    /// other properties are preserved on the node as categorical (string) or
    /// continuous (numeric) attributes, keyed by property name. `LineString`
    /// features become edges, connecting whichever two nodes have matching
    /// endpoint coordinates; their `weight` property is used if present
    /// (defaulting to `1.0`) and each edge is added symmetrically.
    ///
    /// - Parameter data: The raw GeoJSON file contents.
    /// - Returns: The parsed graph.
    /// - Throws: `GraphImportError.invalidGeoJSON` if the data isn't a valid `FeatureCollection`,
    ///   `.missingNodeName` for a `Point` without a `name`, or `.unresolvedEdgeEndpoint` for a
    ///   `LineString` whose endpoint matches no `Point`.
    public static func importGeoJSON(data: Data) throws -> Graph {
        let collection: GeoJSONFeatureCollection
        do {
            collection = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
        } catch {
            throw GraphImportError.invalidGeoJSON(error.localizedDescription)
        }

        let graph = Graph()
        var nameByCoordinate: [GeoJSONCoordinateKey: String] = [:]

        for feature in collection.features {
            guard case .point(let coordinates) = feature.geometry.coordinates, coordinates.count == 2 else { continue }

            var properties = feature.properties
            guard let name = properties.removeString("name") else {
                throw GraphImportError.missingNodeName
            }
            let size = properties.removeNumber("size") ?? 1.0
            let color = properties.removeString("color").flatMap { Color(hex: $0) } ?? .red

            var categorical: [String: String] = [:]
            var continuous: [String: Double] = [:]
            for (key, scalar) in properties.values {
                switch scalar {
                case .string(let s): categorical[key] = s
                case .number(let d): continuous[key] = d
                case .bool(let b): categorical[key] = b ? "true" : "false"
                case .null: continue
                }
            }

            let coordinate = CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0])
            graph.addNode(name: name, size: size, color: color, coordinate: coordinate,
                          categoricalAttributes: categorical, continuousAttributes: continuous)
            nameByCoordinate[GeoJSONCoordinateKey(coordinates)] = name
        }

        for feature in collection.features {
            guard case .lineString(let coordinates) = feature.geometry.coordinates,
                  coordinates.count == 2 else { continue }
            guard let fromName = nameByCoordinate[GeoJSONCoordinateKey(coordinates[0])],
                  let toName = nameByCoordinate[GeoJSONCoordinateKey(coordinates[1])] else {
                throw GraphImportError.unresolvedEdgeEndpoint
            }
            let weight = feature.properties.numberValue("weight") ?? 1.0
            graph.addEdge(from: fromName, to: toName, weight: weight, symmetric: true)
        }

        return graph
    }

    /// Parses a GeoJSON file at the given URL. See ``importGeoJSON(data:)`` for the format.
    ///
    /// - Parameter url: The location of the GeoJSON file.
    /// - Returns: The parsed graph.
    /// - Throws: Any error from reading the file, or a ``GraphImportError`` from parsing it.
    public static func importGeoJSON(contentsOf url: URL) throws -> Graph {
        try importGeoJSON(data: try Data(contentsOf: url))
    }
}

// MARK: - GeoJSON decoding model

/// A hand-rolled minimal GeoJSON model — only the shapes `importGeoJSON`
/// actually needs (`FeatureCollection` of `Point`/`LineString` features).

extension Color {
    /// Parses a `"#RRGGBB"` hex color string. Returns `nil` for any other shape.
    ///
    /// - Parameter hex: The color string, with or without a leading `#`.
    init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        guard hexString.count == 6, let value = UInt32(hexString, radix: 16) else { return nil }
        self = Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
