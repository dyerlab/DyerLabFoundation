//
//  GeoJSONImport.swift
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
            guard case .lineString(let coordinates) = feature.geometry.coordinates, coordinates.count == 2 else { continue }
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
    public static func importGeoJSON(contentsOf url: URL) throws -> Graph {
        try importGeoJSON(data: try Data(contentsOf: url))
    }
}

// MARK: - GeoJSON decoding model

/// A hand-rolled minimal GeoJSON model — only the shapes `importGeoJSON`
/// actually needs (`FeatureCollection` of `Point`/`LineString` features).

struct GeoJSONFeatureCollection: Decodable {
    let features: [GeoJSONFeature]
}

struct GeoJSONFeature: Decodable {
    let geometry: GeoJSONGeometry
    let properties: GeoJSONProperties
}

struct GeoJSONGeometry: Decodable {
    let coordinates: GeoJSONCoordinates
}

/// A GeoJSON `coordinates` array, whose shape depends on the geometry type:
/// a flat `[lon, lat]` pair for `Point`, or a list of such pairs for `LineString`.
enum GeoJSONCoordinates: Decodable {
    case point([Double])
    case lineString([[Double]])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let nested = try? container.decode([[Double]].self) {
            self = .lineString(nested)
        } else {
            self = .point(try container.decode([Double].self))
        }
    }
}

/// A feature's freeform `properties` object, decoded generically so any
/// property name/type combination the source data happens to carry survives
/// the round trip (beyond the handful of well-known keys `importGeoJSON` reads directly).
struct GeoJSONProperties: Decodable {
    var values: [String: GeoJSONScalar]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        values = try container.decode([String: GeoJSONScalar].self)
    }

    func stringValue(_ key: String) -> String? {
        if case .string(let s)? = values[key] { return s }
        return nil
    }

    func numberValue(_ key: String) -> Double? {
        if case .number(let d)? = values[key] { return d }
        return nil
    }

    mutating func removeString(_ key: String) -> String? {
        defer { values.removeValue(forKey: key) }
        return stringValue(key)
    }

    mutating func removeNumber(_ key: String) -> Double? {
        defer { values.removeValue(forKey: key) }
        return numberValue(key)
    }
}

/// A single untyped JSON value, as found inside a GeoJSON feature's `properties` object.
enum GeoJSONScalar: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let d = try? container.decode(Double.self) {
            self = .number(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON scalar")
        }
    }
}

/// Identifies a `Point`'s coordinates so `LineString` endpoints can be matched back to nodes.
struct GeoJSONCoordinateKey: Hashable {
    let longitude: Double
    let latitude: Double

    init(_ pair: [Double]) {
        longitude = pair[0]
        latitude = pair[1]
    }
}

extension Color {
    /// Parses a `"#RRGGBB"` hex color string. Returns `nil` for any other shape.
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
