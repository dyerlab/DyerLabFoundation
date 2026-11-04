//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CoordinateReferenceSystem+Definition.swift
//  Matrix
//
//  Reads back the `definition` strings: "EPSG:n", or a PROJ string for
//  tmerc, utm, aea or longlat, which is what R's terra and sf print with
//  crs(x, proj = TRUE). Only the PROJ parameters those methods take are read;
//  anything else (+towgs84, +no_defs, +type=crs) is ignored.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension CoordinateReferenceSystem {

    /// The system a definition string names.
    ///
    /// Accepts `"EPSG:n"` for any code ``init(epsg:)`` recognises, and PROJ strings using `+proj=longlat`,
    /// `utm`, `tmerc` or `aea`, such as `"+proj=utm +zone=12 +datum=WGS84 +units=m +no_defs"`.
    ///
    /// - Parameter definition: The definition.
    /// - Returns: The system, or `nil` for an unrecognised code, another projection, units other than metres,
    ///   or an ellipsoid that isn't given.
    public init?(definition: String) {
        let trimmed = definition.trimmingCharacters(in: .whitespaces)
        if trimmed.uppercased().hasPrefix("EPSG:") {
            guard let code = Int(trimmed.dropFirst(5)), let crs = CoordinateReferenceSystem(epsg: code) else {
                return nil
            }
            self = crs
            return
        }
        var parameters: [String: String] = [:]
        for token in trimmed.split(separator: " ") where token.hasPrefix("+") {
            let parts = token.dropFirst().split(separator: "=", maxSplits: 1).map(String.init)
            parameters[parts[0]] = parts.count > 1 ? parts[1] : ""
        }
        guard let method = parameters["proj"], parameters["units"].map({ $0 == "m" }) ?? true,
              let ellipsoid = Self.ellipsoid(parameters) else { return nil }
        func number(_ key: String, _ fallback: Double = 0) -> Double? {
            guard let text = parameters[key] else { return fallback }
            return Double(text)
        }
        switch method {
        case "longlat", "latlong", "lonlat", "latlon":
            self = .geographic(epsg: ellipsoid == .wgs84 ? 4326 : 4269)
        case "utm":
            guard let zoneText = parameters["zone"], let zone = Int(zoneText),
                  let projection = MapProjection.utm(zone: zone, southern: parameters["south"] != nil,
                                                     ellipsoid: ellipsoid) else { return nil }
            self = .projected(projection, epsg: nil)
        case "tmerc":
            guard let latitude = number("lat_0"), let longitude = number("lon_0"),
                  let scale = parameters["k"] != nil ? number("k") : number("k_0", 1),
                  let x0 = number("x_0"), let y0 = number("y_0"),
                  let projection = MapProjection(transverseMercatorOn: ellipsoid, latitudeOfOrigin: latitude,
                                                 centralMeridian: longitude, scaleFactor: scale,
                                                 falseEasting: x0, falseNorthing: y0) else { return nil }
            self = .projected(projection, epsg: nil)
        case "aea":
            guard let latitude = number("lat_0"), let longitude = number("lon_0"),
                  let parallel1 = parameters["lat_1"].flatMap(Double.init),
                  let parallel2 = number("lat_2", parallel1),
                  let x0 = number("x_0"), let y0 = number("y_0"),
                  let projection = MapProjection(albersEqualAreaOn: ellipsoid, latitudeOfOrigin: latitude,
                                                 centralMeridian: longitude, standardParallel1: parallel1,
                                                 standardParallel2: parallel2, falseEasting: x0,
                                                 falseNorthing: y0) else { return nil }
            self = .projected(projection, epsg: nil)
        default:
            return nil
        }
    }

    /// The ellipsoid a PROJ string names through `+datum`, `+ellps`, or `+a` with `+rf`.
    private static func ellipsoid(_ parameters: [String: String]) -> Ellipsoid? {
        switch parameters["datum"] ?? parameters["ellps"] {
        case "WGS84": return .wgs84
        case "NAD83", "GRS80": return .grs80
        case .some: return nil
        case nil:
            guard let a = parameters["a"].flatMap(Double.init), let rf = parameters["rf"].flatMap(Double.init) else {
                return nil
            }
            return Ellipsoid(semiMajorAxis: a, inverseFlattening: rf)
        }
    }
}
