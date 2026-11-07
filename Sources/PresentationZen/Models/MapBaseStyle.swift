//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MapBaseStyle.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import MapKit
import SwiftUI

/// A map's base layer.
public enum MapBaseStyle: String, CaseIterable, Identifiable, Sendable {
    /// The standard road map.
    case standard
    /// Satellite imagery.
    case satellite

    /// The style itself.
    public var id: Self { self }

    /// The MapKit style that draws this layer.
    public var mapStyle: MapStyle {
        switch self {
        case .standard: .standard
        case .satellite: .imagery
        }
    }
}
