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
//  MapPlacard.swift
//  GeneticStudio
//
//  Created by Rodney Dyer on 5/2/24.
//-
import Foundation
import CoreLocation

/// A lightweight annotation model for displaying a labelled point on a map.
public struct MapPlacard {

    /// Unique identifier for this placard.
    public let id: UUID

    /// Primary label displayed at the map point.
    public var title: String

    /// Secondary label displayed below the title.
    public var subtitle: String

    /// The geographic coordinate of this placard.
    public var coordinate: CLLocationCoordinate2D

    /// SF Symbol name (or custom asset name) used as the map icon.
    public var icon: String

    /// Creates a placard with the specified label, coordinate, and optional icon.
    ///
    /// - Parameters:
    ///   - title: Primary label displayed at the map point.
    ///   - subtitle: Secondary label displayed below the title.
    ///   - coordinate: The geographic coordinate.
    ///   - icon: SF Symbol name for the icon (default: `"target"`).
    public init(title: String, subtitle: String, coordinate: CLLocationCoordinate2D, icon: String = "target") {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.icon = icon
    }
}


extension MapPlacard: Identifiable, Hashable, Equatable {
    
    /// Two placards are equal if they share the same `id`, or — when IDs differ — if
    /// their coordinates match exactly.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand placard.
    ///   - rhs: The right-hand placard.
    /// - Returns: `true` if the placards represent the same map point.
    static public func == (lhs: MapPlacard, rhs: MapPlacard) -> Bool {
        
        if lhs.id != rhs.id {
            return lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
        }
        return true
    }
    
    /// Hashes the placard's coordinate into the supplied hasher.
    ///
    /// Must hash the same property `==` actually keys equality on. Two
    /// distinct placards can be `==` via matching coordinates alone (see
    /// above) — `id` is never a distinguishing factor in practice, since two
    /// separately-constructed placards are never assigned equal `id`s, so the
    /// "same id" branch of `==` only ever fires for a placard compared with
    /// itself (trivially also coordinate-equal). Hashing `id` instead of
    /// coordinate would violate `Hashable`'s `a == b ⇒ hash(a) == hash(b)`
    /// contract for the same-coordinate/different-id case.
    ///
    /// - Parameter hasher: The hasher to feed.
    public func hash(into hasher: inout Hasher) {
        hasher.combine( coordinate.latitude )
        hasher.combine( coordinate.longitude )
    }
    
}


extension MapPlacard {

    /// A small set of sample placards near Richmond, VA, useful for previews and testing.
    static public var randomSites: [MapPlacard] {
        return [
            MapPlacard(title: "RVA", subtitle: "Richmond Virginia", coordinate: CLLocationCoordinate2D(latitude: 37.5407, longitude: -77.4360 ) ),
            MapPlacard(title: "COTU", subtitle: "Ashland Virginia", coordinate: CLLocationCoordinate2D(latitude: 37.7590, longitude: -77.480 ), icon: "mug" ),
            MapPlacard(title: "Hopewell", subtitle: "Hopwell Virginia", coordinate: CLLocationCoordinate2D(latitude: 37.3043, longitude: -77.2872 ) ),
        ]
    }
}
