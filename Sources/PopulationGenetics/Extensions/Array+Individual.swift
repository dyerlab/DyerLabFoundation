//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Array+Individual.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 5/30/25.
//


import Foundation
import CoreLocation

/// Extensions for arrays of `Individual` objects to support spatial operations and mapping.
extension Array where Element == Individual {

    /// Extracts all valid geographic coordinates from individuals in the array.
    ///
    /// Only includes individuals that have both latitude and longitude defined.
    ///
    /// - Returns: An array of `CLLocationCoordinate2D` for all spatially-located individuals.
    public var coordinates: [CLLocationCoordinate2D] {
        var ret = [CLLocationCoordinate2D]()
        for ind in self {
            if let lat = ind.latitude,
                let lon = ind.longitude {
                ret.append( CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        }
        return ret
    }

    /// Creates map placards for all spatially-located individuals in the array.
    ///
    /// Each placard displays the individual's name as the title and its coordinate
    /// as the subtitle. Only includes individuals with valid coordinates. This is a
    /// pure `Individual` extension with no store access, so genotype counts (which
    /// require a `PopGenStore` to look up) aren't available here — callers that want
    /// per-individual genotype counts should query the store directly.
    ///
    /// - Returns: An array of `MapPlacard` objects suitable for display on maps.
    public var placards: [MapPlacard] {
        var ret = [MapPlacard]()
        for ind in self {
            if let lat = ind.latitude,
               let lon = ind.longitude {
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let subtitle = String(format: "%.4f, %.4f", lat, lon)
                let placard = MapPlacard(title: ind.name, subtitle: subtitle, coordinate: coord)
                ret.append( placard)
            }
        }
        return ret
    }



}
