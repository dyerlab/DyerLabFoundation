//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MapProjection+AlbersEqualArea.swift
//  Matrix
//
//  Albers equal-area conic on the ellipsoid, from Snyder (1987), Map
//  Projections: A Working Manual, USGS Professional Paper 1395, pp. 101–102
//  (eqs. 3-12, 3-16, 14-3 to 14-6, 14-19 to 14-21). The inverse solves for
//  latitude by Snyder's iteration (eq. 3-16), as PROJ does.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension MapProjection {

    /// The cone constants for this projection.
    private struct AlbersCone {
        let eccentricity: Double
        /// The cone constant, n.
        let n: Double
        /// Snyder's C.
        let c: Double
        /// The radius of the parallel through the origin, ρ₀.
        let rho0: Double
        let semiMajorAxis: Double

        init(_ projection: MapProjection) {
            let e = projection.ellipsoid.eccentricity
            eccentricity = e
            semiMajorAxis = projection.ellipsoid.semiMajorAxis
            let phi1 = projection.standardParallel1 * .pi / 180
            let phi2 = projection.standardParallel2 * .pi / 180
            let m1 = Self.m(phi1, e)
            let q1 = Self.q(phi1, e)
            if abs(phi1 - phi2) > 1e-10 {
                let m2 = Self.m(phi2, e)
                n = (m1 * m1 - m2 * m2) / (Self.q(phi2, e) - q1)
            } else {
                n = sin(phi1)
            }
            c = m1 * m1 + n * q1
            rho0 = semiMajorAxis * (c - n * Self.q(projection.latitudeOfOrigin * .pi / 180, e)).squareRoot() / n
        }

        /// Snyder's m (eq. 14-15): the parallel's radius on a unit ellipsoid.
        static func m(_ phi: Double, _ e: Double) -> Double {
            let s = sin(phi)
            return cos(phi) / (1 - e * e * s * s).squareRoot()
        }

        /// Snyder's q (eq. 3-12): proportional to the area between the equator and the parallel.
        static func q(_ phi: Double, _ e: Double) -> Double {
            let s = sin(phi)
            return (1 - e * e) * (s / (1 - e * e * s * s) - log((1 - e * s) / (1 + e * s)) / (2 * e))
        }

        /// The latitude with a given q, by Snyder's iteration (eq. 3-16).
        func latitude(q target: Double) -> Double? {
            let e = eccentricity
            // q at the pole; a q beyond it (from rounding at the apex) is the pole itself.
            let qPole = Self.q(.pi / 2, e)
            if abs(target) >= qPole - 1e-12 { return target > 0 ? .pi / 2 : -.pi / 2 }
            var phi = asin(target / 2)
            for _ in 0 ..< 20 {
                let s = sin(phi)
                let denominator = 1 - e * e * s * s
                let step = denominator * denominator / (2 * cos(phi))
                    * (target / (1 - e * e) - s / denominator + log((1 - e * s) / (1 + e * s)) / (2 * e))
                phi += step
                if abs(step) < 1e-13 { return phi }
            }
            return nil
        }
    }

    func albersForward(longitude: Double, latitude: Double) -> (x: Double, y: Double)? {
        let cone = AlbersCone(self)
        let q = AlbersCone.q(latitude * .pi / 180, cone.eccentricity)
        let radicand = cone.c - cone.n * q
        guard radicand >= 0 else { return nil }
        let rho = cone.semiMajorAxis * radicand.squareRoot() / cone.n
        let theta = cone.n * Self.wrappedRadians(longitude - centralMeridian)
        return (falseEasting + rho * sin(theta), falseNorthing + cone.rho0 - rho * cos(theta))
    }

    func albersInverse(x: Double, y: Double) -> (longitude: Double, latitude: Double)? {
        let cone = AlbersCone(self)
        // With a negative cone constant (a southern cone) x, y and ρ₀ all change sign (Snyder p. 102).
        let sign: Double = cone.n < 0 ? -1 : 1
        let dx = sign * (x - falseEasting)
        let dy = sign * (cone.rho0 - (y - falseNorthing))
        let rho = (dx * dx + dy * dy).squareRoot()
        let theta = atan2(dx, dy)
        let q = (cone.c - rho * rho * cone.n * cone.n / (cone.semiMajorAxis * cone.semiMajorAxis)) / cone.n
        guard let phi = cone.latitude(q: q) else { return nil }
        let longitude = centralMeridian + theta / cone.n * 180 / .pi
        guard abs(longitude - centralMeridian) <= 180 + 1e-9 else { return nil }
        return (longitude, phi * 180 / .pi)
    }
}
