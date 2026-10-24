//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GeoJSONModel.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.08.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import SwiftUI
import CoreLocation

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
