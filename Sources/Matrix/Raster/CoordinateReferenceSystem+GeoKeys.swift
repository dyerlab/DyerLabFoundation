//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CoordinateReferenceSystem+GeoKeys.swift
//  Matrix
//
//  A GeoTIFF names its coordinate system with an EPSG code (what GDAL writes
//  for any system in the EPSG database) or, for a custom projection, spells
//  out the method and parameters as GeoKeys (OGC GeoTIFF 1.1, §7.5). Both
//  are read; GDAL puts Albers' origin in the natural-origin keys, other
//  writers in the false-origin or centre keys, so all three are accepted.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension CoordinateReferenceSystem {

    // GeoKey IDs.
    private enum Key {
        static let modelType = 1024
        static let citation = 1026
        static let geographicType = 2048
        static let geodeticDatum = 2050
        static let ellipsoid = 2056
        static let semiMajorAxis = 2057
        static let inverseFlattening = 2059
        static let projectedType = 3072
        static let projection = 3074
        static let coordinateTransform = 3075
        static let linearUnits = 3076
        static let standardParallel1 = 3078
        static let standardParallel2 = 3079
        static let naturalOriginLongitude = 3080
        static let naturalOriginLatitude = 3081
        static let falseEasting = 3082
        static let falseNorthing = 3083
        static let falseOriginLongitude = 3084
        static let falseOriginLatitude = 3085
        static let falseOriginEasting = 3086
        static let falseOriginNorthing = 3087
        static let centerLongitude = 3088
        static let centerLatitude = 3089
        static let scaleAtNaturalOrigin = 3092
        static let scaleAtCenter = 3093
    }

    private static let userDefined = 32767

    /// The coordinate system a GeoTIFF's GeoKeys describe.
    ///
    /// - Throws: ``RasterImportError/unsupportedCoordinateSystem(_:)`` for anything other than WGS 84/NAD83
    ///   longitude and latitude, or a UTM or Albers projection in metres.
    init(geoKeys keys: GeoKeyDirectory) throws {
        let isProjected = keys.shorts[Key.modelType].map { $0 == 1 } ?? (keys.shorts[Key.projectedType] != nil)
        if let modelType = keys.shorts[Key.modelType], modelType != 1, modelType != 2 {
            throw RasterImportError.unsupportedCoordinateSystem("model type \(modelType)")
        }
        self = isProjected ? try Self.projected(keys) : try Self.geographic(keys)
    }

    private static func geographic(_ keys: GeoKeyDirectory) throws -> CoordinateReferenceSystem {
        if let code = keys.shorts[Key.geographicType], code != userDefined {
            guard geographicEPSGCodes.contains(code) else { throw unsupported("EPSG:\(code)", keys) }
            return .geographic(epsg: code)
        }
        // A user-defined geographic system on the WGS 84 or NAD83 datum is the same thing for our purposes.
        switch keys.shorts[Key.geodeticDatum] {
        case 6326: return .geographic(epsg: 4326)
        case 6269: return .geographic(epsg: 4269)
        case let datum?: throw unsupported("datum EPSG:\(datum)", keys)
        case nil: throw unsupported("an unspecified coordinate system", keys)
        }
    }

    private static func projected(_ keys: GeoKeyDirectory) throws -> CoordinateReferenceSystem {
        if let code = keys.shorts[Key.projectedType], code != userDefined {
            guard let crs = CoordinateReferenceSystem(epsg: code), !crs.isGeographic else {
                throw unsupported("EPSG:\(code)", keys)
            }
            return crs
        }
        if let units = keys.shorts[Key.linearUnits], units != 9001 {
            throw unsupported("linear units EPSG:\(units) rather than metres", keys)
        }
        let ellipsoid = try ellipsoid(keys)
        // A standard projection code without a system code: EPSG's UTM projection codes are 16001–16060 (north)
        // and 16101–16160 (south).
        if let code = keys.shorts[Key.projection], code != userDefined {
            switch code {
            case 16001 ... 16060:
                return .projected(MapProjection.utm(zone: code - 16000, ellipsoid: ellipsoid)!, epsg: nil)
            case 16101 ... 16160:
                return .projected(MapProjection.utm(zone: code - 16100, southern: true, ellipsoid: ellipsoid)!,
                                  epsg: nil)
            default:
                throw unsupported("projection EPSG:\(code)", keys)
            }
        }
        let projection: MapProjection?
        let d = keys.doubles
        let longitude = d[Key.naturalOriginLongitude] ?? d[Key.falseOriginLongitude] ?? d[Key.centerLongitude] ?? 0
        let latitude = d[Key.naturalOriginLatitude] ?? d[Key.falseOriginLatitude] ?? d[Key.centerLatitude] ?? 0
        let falseEasting = d[Key.falseEasting] ?? d[Key.falseOriginEasting] ?? 0
        let falseNorthing = d[Key.falseNorthing] ?? d[Key.falseOriginNorthing] ?? 0
        switch keys.shorts[Key.coordinateTransform] {
        case 1:
            projection = MapProjection(transverseMercatorOn: ellipsoid, latitudeOfOrigin: latitude,
                                       centralMeridian: longitude,
                                       scaleFactor: d[Key.scaleAtNaturalOrigin] ?? d[Key.scaleAtCenter] ?? 1,
                                       falseEasting: falseEasting, falseNorthing: falseNorthing)
        case 11:
            guard let parallel1 = d[Key.standardParallel1], let parallel2 = d[Key.standardParallel2] else {
                throw unsupported("an Albers projection without standard parallels", keys)
            }
            projection = MapProjection(albersEqualAreaOn: ellipsoid, latitudeOfOrigin: latitude,
                                       centralMeridian: longitude, standardParallel1: parallel1,
                                       standardParallel2: parallel2, falseEasting: falseEasting,
                                       falseNorthing: falseNorthing)
        case let method?:
            throw unsupported(methodName(method), keys)
        case nil:
            throw unsupported("a projection with no method", keys)
        }
        guard let projection else { throw unsupported("projection parameters out of range", keys) }
        return .projected(projection, epsg: nil)
    }

    /// The ellipsoid of a user-defined projected system, from its geographic system, datum or ellipsoid keys.
    private static func ellipsoid(_ keys: GeoKeyDirectory) throws -> Ellipsoid {
        switch keys.shorts[Key.geographicType] {
        case 4326: return .wgs84
        case 4269, 4258, 4152, 4759, 6318: return .grs80    // NAD83 and its realizations, ETRS89
        default: break
        }
        switch keys.shorts[Key.geodeticDatum] {
        case 6326: return .wgs84
        case 6269, 6258, 6152, 6759, 1116: return .grs80
        default: break
        }
        switch keys.shorts[Key.ellipsoid] {
        case 7030: return .wgs84
        case 7019: return .grs80
        default: break
        }
        if let a = keys.doubles[Key.semiMajorAxis], let inverse = keys.doubles[Key.inverseFlattening],
           let ellipsoid = Ellipsoid(semiMajorAxis: a, inverseFlattening: inverse) {
            return ellipsoid
        }
        throw unsupported("a projection on an unspecified ellipsoid", keys)
    }

    /// A readable name for a GeoTIFF coordinate-transform code that isn't supported.
    private static func methodName(_ code: Int) -> String {
        switch code {
        case 7: "a Mercator projection"
        case 8, 9: "a Lambert conformal conic projection"
        case 10: "a Lambert azimuthal equal-area projection"
        case 12: "an azimuthal equidistant projection"
        case 13: "an equidistant conic projection"
        case 15: "a polar stereographic projection"
        default: "projection method \(code)"
        }
    }

    /// The unsupported-system error, with the file's own name for its system appended when it has one.
    private static func unsupported(_ detail: String, _ keys: GeoKeyDirectory) -> RasterImportError {
        if let citation = keys.strings[Key.citation], !citation.isEmpty, citation != "unknown" {
            return .unsupportedCoordinateSystem("\(detail), \"\(citation)\"")
        }
        return .unsupportedCoordinateSystem(detail)
    }
}
