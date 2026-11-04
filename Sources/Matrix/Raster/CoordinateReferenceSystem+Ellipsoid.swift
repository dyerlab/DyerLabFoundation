//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CoordinateReferenceSystem+Ellipsoid.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension CoordinateReferenceSystem {

    /// The ellipsoid coordinates are given on: WGS 84 for EPSG:4326, GRS 80 for EPSG:4269, or the projection's.
    public var ellipsoid: Ellipsoid {
        switch self {
        case .geographic(let epsg): epsg == 4269 ? .grs80 : .wgs84
        case .projected(let projection, _): projection.ellipsoid
        }
    }
}
