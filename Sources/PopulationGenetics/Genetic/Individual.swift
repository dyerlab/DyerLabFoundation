//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Individual.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 5/30/25.
//
//  Represents an individual in a population genetics dataset, including metadata
//  like spatial coordinates and associated genetic and stratification information.
//

import CoreLocation
import Foundation

/// Represents an individual in a population genetics context, holding identifying information,
/// spatial coordinates, and relationships to genetic and stratification data.
public struct Individual: Codable, Hashable, Sendable, Identifiable {

    /// Unique identifier for the individual.
    public var id: UUID

    /// A name or label assigned to the individual.
    public var name: String

    /// Latitude of the individual's sampling location (if available).
    public var latitude: Double?

    /// Longitude of the individual's sampling location (if available).
    public var longitude: Double?

    /// Initializes a new individual with optional name and coordinates.
    public init(name: String = "", latitude: Double? = nil, longitude: Double? = nil) {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Indicates whether the individual has valid spatial coordinates.
    public var isSpatial: Bool {
        return latitude != nil && longitude != nil
    }

    /// Returns the individual's coordinates as a `CLLocationCoordinate2D` if available.
    public var coordinate: CLLocationCoordinate2D? {
        if let lat = latitude, let long = longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: long)
        } else {
            return nil
        }
    }

}
