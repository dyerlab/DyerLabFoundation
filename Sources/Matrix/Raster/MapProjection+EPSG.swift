//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MapProjection+EPSG.swift
//  Matrix
//
//  The projected EPSG codes recognised without PROJ. Parameters are PROJ's
//  own (checked with terra::crs("EPSG:n", proj = TRUE), PROJ 9.5, 2026-11-04).
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension MapProjection {

    /// The projection of a projected EPSG code, or `nil` if the code isn't recognised.
    ///
    /// See ``CoordinateReferenceSystem/init(epsg:)`` for the codes covered.
    ///
    /// - Parameter epsg: The EPSG code.
    public init?(epsg: Int) {
        let projection: MapProjection?
        switch epsg {
        case 32601 ... 32660:   // WGS 84 / UTM zones 1N–60N
            projection = .utm(zone: epsg - 32600)
        case 32701 ... 32760:   // WGS 84 / UTM zones 1S–60S
            projection = .utm(zone: epsg - 32700, southern: true)
        case 26901 ... 26923:   // NAD83 / UTM zones 1N–23N
            projection = .utm(zone: epsg - 26900, ellipsoid: .grs80)
        case 6330 ... 6348:     // NAD83(2011) / UTM zones 1N–19N
            projection = .utm(zone: epsg - 6329, ellipsoid: .grs80)
        case 6328, 6329:        // NAD83(2011) / UTM zones 59N, 60N
            projection = .utm(zone: epsg - 6269, ellipsoid: .grs80)
        case 25828 ... 25838:   // ETRS89 / UTM zones 28N–38N
            projection = .utm(zone: epsg - 25800, ellipsoid: .grs80)
        case 5070, 5071, 5072, 6350:    // NAD83 (and realizations) / Conus Albers
            projection = .nad83Albers(origin: 23, meridian: -96, parallels: (29.5, 45.5))
        case 3338, 6393:        // NAD83 / Alaska Albers
            projection = .nad83Albers(origin: 50, meridian: -154, parallels: (55, 65))
        case 3310:              // NAD83 / California Albers
            projection = .nad83Albers(origin: 0, meridian: -120, parallels: (34, 40.5), falseNorthing: -4_000_000)
        case 3005:              // NAD83 / BC Albers
            projection = .nad83Albers(origin: 45, meridian: -126, parallels: (50, 58.5), falseEasting: 1_000_000)
        default:
            projection = nil
        }
        guard let projection else { return nil }
        self = projection
    }

    private static func nad83Albers(origin: Double,
                                    meridian: Double,
                                    parallels: (Double, Double),
                                    falseEasting: Double = 0,
                                    falseNorthing: Double = 0) -> MapProjection? {
        MapProjection(albersEqualAreaOn: .grs80, latitudeOfOrigin: origin, centralMeridian: meridian,
                      standardParallel1: parallels.0, standardParallel2: parallels.1,
                      falseEasting: falseEasting, falseNorthing: falseNorthing)
    }
}
