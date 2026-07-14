//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  MappableNode.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 5/21/25.
//

import Foundation
import CoreLocation

/// A protocol for types that can provide spatial coordinates for mapping.
///
/// Conforming types can be displayed on maps by providing a
/// `CLLocationCoordinate2D`, standardizing spatial data access across
/// otherwise-unrelated types so map-rendering code (e.g. `MapView`) can work
/// against `any MappableNode` instead of a specific concrete type.
public protocol MappableNode {
    /// The geographic coordinate for this node, if available.
    ///
    /// Returns `nil` if the node has no spatial information.
    var mapCoordinate: CLLocationCoordinate2D? { get }
}
