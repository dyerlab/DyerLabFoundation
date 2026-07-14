//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2025 The Dyer Laboratory.  All Rights Reserved.
//
//  DefaultLocations.swift
//
//
//  Created by Rodney Dyer on 12/9/21.
//

import Foundation
import MapKit

/// Default map center and region used when no sampling locations are available.
///
/// Defaults to Richmond, VA.
public struct DefaultLocations {

    /// Default map center coordinate.
    static public let center = CLLocationCoordinate2D( latitude: 37.5407,
                                                       longitude: -77.4360 )

    /// Default map region, a 1000×1000 meter span centered on `center`.
    static public let region = MKCoordinateRegion( center: DefaultLocations.center,
                                                   latitudinalMeters: 1000,
                                                   longitudinalMeters: 1000)
}
