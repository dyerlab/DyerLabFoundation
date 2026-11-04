//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Ellipsoid+Geodesic.swift
//  Matrix
//
//  The length of the shortest path between two points on the ellipsoid, by
//  Vincenty's (1975) inverse method. It agrees with Karney's algorithm (which
//  R's raster::pointDistance and geosphere::distGeo use) to a fraction of a
//  millimetre, except for nearly antipodal points, where it can fail to
//  converge. The resistance cell graph only ever asks for neighbouring cells.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension Ellipsoid {

    /// The geodesic distance between two points, in metres.
    ///
    /// ```swift
    /// Ellipsoid.wgs84.distance(fromLongitude: -111.2, latitude: 30.0, toLongitude: -111.19, latitude: 30.0)
    /// // 964.4
    /// ```
    ///
    /// - Parameters:
    ///   - longitude1: The first point's longitude, in degrees.
    ///   - latitude1: The first point's latitude, in degrees.
    ///   - longitude2: The second point's longitude, in degrees.
    ///   - latitude2: The second point's latitude, in degrees.
    /// - Returns: The distance along the ellipsoid, or `nil` if a coordinate isn't finite or the points are so
    ///   nearly antipodal that the method doesn't converge.
    public func distance(fromLongitude longitude1: Double, latitude latitude1: Double,
                         toLongitude longitude2: Double, latitude latitude2: Double) -> Double? {
        guard [longitude1, latitude1, longitude2, latitude2].allSatisfy(\.isFinite) else { return nil }
        let f = flattening
        let a = semiMajorAxis
        let b = a * (1 - f)
        let radians = Double.pi / 180
        let longitudeDifference = MapProjection.wrappedRadians(longitude2 - longitude1)
        let u1 = atan((1 - f) * tan(latitude1 * radians))
        let u2 = atan((1 - f) * tan(latitude2 * radians))
        let (sinU1, cosU1, sinU2, cosU2) = (sin(u1), cos(u1), sin(u2), cos(u2))

        var lambda = longitudeDifference
        for _ in 0 ..< 200 {
            let (sinLambda, cosLambda) = (sin(lambda), cos(lambda))
            let crossTerm = cosU1 * sinU2 - sinU1 * cosU2 * cosLambda
            let sinSigma = ((cosU2 * sinLambda) * (cosU2 * sinLambda) + crossTerm * crossTerm).squareRoot()
            if sinSigma == 0 { return 0 }
            let cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda
            let sigma = atan2(sinSigma, cosSigma)
            let sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma
            let cosSquaredAlpha = 1 - sinAlpha * sinAlpha
            // On the equator cos²α is 0 and the midpoint term drops out.
            let cos2SigmaM = cosSquaredAlpha == 0 ? 0 : cosSigma - 2 * sinU1 * sinU2 / cosSquaredAlpha
            let c = f / 16 * cosSquaredAlpha * (4 + f * (4 - 3 * cosSquaredAlpha))
            let previous = lambda
            lambda = longitudeDifference + (1 - c) * f * sinAlpha
                * (sigma + c * sinSigma * (cos2SigmaM + c * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)))
            guard abs(lambda - previous) < 1e-13 else { continue }

            let uSquared = cosSquaredAlpha * (a * a - b * b) / (b * b)
            let bigA = 1 + uSquared / 16384 * (4096 + uSquared * (-768 + uSquared * (320 - 175 * uSquared)))
            let bigB = uSquared / 1024 * (256 + uSquared * (-128 + uSquared * (74 - 47 * uSquared)))
            let deltaSigma = bigB * sinSigma * (cos2SigmaM + bigB / 4 * (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)
                - bigB / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) * (-3 + 4 * cos2SigmaM * cos2SigmaM)))
            return b * bigA * (sigma - deltaSigma)
        }
        return nil
    }
}
