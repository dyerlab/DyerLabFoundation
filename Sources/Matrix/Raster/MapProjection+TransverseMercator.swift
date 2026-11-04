//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MapProjection+TransverseMercator.swift
//  Matrix
//
//  Transverse Mercator by Krüger's series in the third flattening n, to
//  order n⁶, following Karney (2011), "Transverse Mercator with an accuracy
//  of a few nanometers", J. Geodesy 85:475–485, eqs. 7–11, 35–36. Within
//  4,000 km of the central meridian it is accurate to about 5 nm, so it agrees
//  with PROJ's default (Poder/Engsager) algorithm to well under a millimetre.
//  The usual Snyder/USGS series is avoided: it loses millimetres a few degrees
//  out from the central meridian.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension MapProjection {

    /// The series constants for this projection's ellipsoid.
    private struct KruegerSeries {
        /// The rectifying radius, A (Karney eq. 14).
        let rectifyingRadius: Double
        /// α₁…α₆, for the forward series (eq. 35).
        let alpha: [Double]
        /// β₁…β₆, for the inverse series (eq. 36).
        let beta: [Double]
        let eccentricity: Double

        init(_ ellipsoid: Ellipsoid) {
            let f = ellipsoid.flattening
            let n = f / (2 - f)
            let n2 = n * n, n3 = n2 * n, n4 = n3 * n, n5 = n4 * n, n6 = n5 * n
            rectifyingRadius = ellipsoid.semiMajorAxis / (1 + n) * (1 + n2 / 4 + n4 / 64 + n6 / 256)
            alpha = [
                n / 2 - 2 * n2 / 3 + 5 * n3 / 16 + 41 * n4 / 180 - 127 * n5 / 288 + 7891 * n6 / 37800,
                13 * n2 / 48 - 3 * n3 / 5 + 557 * n4 / 1440 + 281 * n5 / 630 - 1_983_433 * n6 / 1_935_360,
                61 * n3 / 240 - 103 * n4 / 140 + 15061 * n5 / 26880 + 167_603 * n6 / 181_440,
                49561 * n4 / 161_280 - 179 * n5 / 168 + 6_601_661 * n6 / 7_257_600,
                34729 * n5 / 80640 - 3_418_889 * n6 / 1_995_840,
                212_378_941 * n6 / 319_334_400,
            ]
            beta = [
                n / 2 - 2 * n2 / 3 + 37 * n3 / 96 - n4 / 360 - 81 * n5 / 512 + 96199 * n6 / 604_800,
                n2 / 48 + n3 / 15 - 437 * n4 / 1440 + 46 * n5 / 105 - 1_118_711 * n6 / 3_870_720,
                17 * n3 / 480 - 37 * n4 / 840 - 209 * n5 / 4480 + 5569 * n6 / 90720,
                4397 * n4 / 161_280 - 11 * n5 / 504 - 830_251 * n6 / 7_257_600,
                4583 * n5 / 161_280 - 108_847 * n6 / 3_991_680,
                20_648_693 * n6 / 638_668_800,
            ]
            eccentricity = ellipsoid.eccentricity
        }

        /// The conformal latitude's tangent, τ′, from the geographic latitude's tangent, τ (Karney eqs. 7–9).
        func conformalTangent(_ tau: Double) -> Double {
            let e = eccentricity
            let sigma = sinh(e * atanh(e * tau / (1 + tau * tau).squareRoot()))
            return tau * (1 + sigma * sigma).squareRoot() - sigma * (1 + tau * tau).squareRoot()
        }

        /// The geographic latitude's tangent from the conformal one, by Newton's method (Karney eqs. 19–21).
        func geographicTangent(_ tauPrime: Double) -> Double {
            let e2 = eccentricity * eccentricity
            var tau = tauPrime / (1 - e2)
            for _ in 0 ..< 8 {
                let estimate = conformalTangent(tau)
                let step = (tauPrime - estimate) / (1 + estimate * estimate).squareRoot()
                    * (1 + (1 - e2) * tau * tau) / ((1 - e2) * (1 + tau * tau).squareRoot())
                tau += step
                if abs(step) < 1e-14 * max(1, abs(tau)) { break }
            }
            return tau
        }

        /// The rectifying-sphere coordinates (ξ, η) of a conformal-sphere point (ξ′, η′) (Karney eq. 11).
        func rectified(xiPrime: Double, etaPrime: Double, coefficients: [Double], sign: Double) -> (Double, Double) {
            var xi = xiPrime
            var eta = etaPrime
            for (index, coefficient) in coefficients.enumerated() {
                let j = Double(2 * (index + 1))
                xi += sign * coefficient * sin(j * xiPrime) * cosh(j * etaPrime)
                eta += sign * coefficient * cos(j * xiPrime) * sinh(j * etaPrime)
            }
            return (xi, eta)
        }

        /// The northing, before scaling and false northing, of a latitude on the central meridian.
        func meridianDistance(latitude: Double) -> Double {
            let xiPrime = atan(conformalTangent(tan(latitude * .pi / 180)))
            return rectifyingRadius * rectified(xiPrime: xiPrime, etaPrime: 0, coefficients: alpha, sign: 1).0
        }
    }

    func transverseMercatorForward(longitude: Double, latitude: Double) -> (x: Double, y: Double)? {
        let lambda = Self.wrappedRadians(longitude - centralMeridian)
        guard abs(lambda) < .pi / 2 else { return nil }
        let series = KruegerSeries(ellipsoid)
        let phi = latitude * .pi / 180
        // At the poles tan φ is infinite, and so is τ′; ξ′ = ±π/2 and η′ = 0 is the limit.
        let tauPrime = abs(latitude) == 90 ? .infinity * latitude : series.conformalTangent(tan(phi))
        let xiPrime = abs(latitude) == 90 ? (latitude > 0 ? .pi / 2 : -.pi / 2) : atan2(tauPrime, cos(lambda))
        let etaPrime = abs(latitude) == 90 ? 0 : asinh(sin(lambda) / (tauPrime * tauPrime + cos(lambda) * cos(lambda)).squareRoot())
        let (xi, eta) = series.rectified(xiPrime: xiPrime, etaPrime: etaPrime, coefficients: series.alpha, sign: 1)
        let northingAtOrigin = series.meridianDistance(latitude: latitudeOfOrigin)
        return (falseEasting + scaleFactor * series.rectifyingRadius * eta,
                falseNorthing + scaleFactor * (series.rectifyingRadius * xi - northingAtOrigin))
    }

    func transverseMercatorInverse(x: Double, y: Double) -> (longitude: Double, latitude: Double)? {
        let series = KruegerSeries(ellipsoid)
        let scaledRadius = scaleFactor * series.rectifyingRadius
        let northingAtOrigin = series.meridianDistance(latitude: latitudeOfOrigin)
        let xi = (y - falseNorthing + scaleFactor * northingAtOrigin) / scaledRadius
        let eta = (x - falseEasting) / scaledRadius
        guard abs(xi) <= .pi / 2 + 1e-12 else { return nil }
        let (xiPrime, etaPrime) = series.rectified(xiPrime: xi, etaPrime: eta, coefficients: series.beta, sign: -1)
        let lambda = atan2(sinh(etaPrime), cos(xiPrime))
        let tauPrime = sin(xiPrime) / (sinh(etaPrime) * sinh(etaPrime) + cos(xiPrime) * cos(xiPrime)).squareRoot()
        guard tauPrime.isFinite else { return nil }
        let phi = atan(series.geographicTangent(tauPrime))
        var longitude = centralMeridian + lambda * 180 / .pi
        if longitude > 180 { longitude -= 360 } else if longitude < -180 { longitude += 360 }
        return (longitude, phi * 180 / .pi)
    }
}
