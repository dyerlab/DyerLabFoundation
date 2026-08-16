//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  DLColor.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 12/1/24.
//

import Foundation
import SwiftUI


/// A color expressed in HSBA components, with shift operations that wrap
/// around `[0, 1]` rather than clamping.
public struct DLColor {

    public let hue: CGFloat
    public let saturation: CGFloat
    public let brightness: CGFloat
    public let alpha: CGFloat

    /// Creates a color from HSBA components.
    ///
    /// - Parameters:
    ///   - hue: Hue, in `[0, 1]`.
    ///   - saturation: Saturation, in `[0, 1]`.
    ///   - brightness: Brightness, in `[0, 1]`.
    ///   - alpha: Opacity, in `[0, 1]`.
    public init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.alpha = alpha
    }

    /// Creates a color from a hex string, e.g. `"#FF8800"`, `"FF8800"`, or `"#FF8800CC"`.
    ///
    /// Accepts 3-digit (`RGB`), 6-digit (`RRGGBB`), and 8-digit (`RRGGBBAA`) forms, with or
    /// without a leading `#`. Returns `nil` if `hex` isn't a valid hex color string.
    ///
    /// - Parameter hex: The hex color string to parse.
    public init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") { digits.removeFirst() }

        switch digits.count {
        case 3:
            digits = digits.map { "\($0)\($0)" }.joined()
        case 6, 8:
            break
        default:
            return nil
        }

        guard var value = UInt64(digits, radix: 16) else { return nil }

        let alpha: CGFloat
        if digits.count == 8 {
            alpha = CGFloat(value & 0xFF) / 255
            value >>= 8
        } else {
            alpha = 1
        }

        let red = CGFloat((value & 0xFF0000) >> 16) / 255
        let green = CGFloat((value & 0x00FF00) >> 8) / 255
        let blue = CGFloat(value & 0x0000FF) / 255

        let maxComponent = max(red, green, blue)
        let minComponent = min(red, green, blue)
        let delta = maxComponent - minComponent

        var hue: CGFloat = 0
        if delta != 0 {
            switch maxComponent {
            case red: hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            case green: hue = (blue - red) / delta + 2
            default: hue = (red - green) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        let saturation = maxComponent == 0 ? 0 : delta / maxComponent

        self.init(hue: hue, saturation: saturation, brightness: maxComponent, alpha: alpha)
    }

    private func shift(_ value: CGFloat, by amount: CGFloat) -> CGFloat {
        return abs((value + amount).truncatingRemainder(dividingBy: 1) )
    }

    /// Returns a copy with `hue` shifted by `amount`, wrapping around `[0, 1]`.
    ///
    /// - Parameter amount: The signed amount to shift by.
    public func shiftHue(by amount : CGFloat) -> DLColor {
        return DLColor(hue: shift(hue, by: amount),
                        saturation: saturation,
                        brightness: brightness, alpha: alpha)
    }

    /// Returns a copy with `brightness` shifted by `amount`, wrapping around `[0, 1]`.
    ///
    /// - Parameter amount: The signed amount to shift by.
    public func shiftBrightness(by amount : CGFloat) -> DLColor {
        return DLColor(hue: hue, saturation: saturation,
                        brightness: shift(brightness, by: amount), alpha: alpha)
    }

    /// Returns a copy with `saturation` shifted by `amount`, wrapping around `[0, 1]`.
    ///
    /// - Parameter amount: The signed amount to shift by.
    public func shiftSaturation(by amount : CGFloat) -> DLColor {
        return DLColor(hue: hue, saturation: shift(saturation, by: amount),
                        brightness: brightness, alpha: alpha)
    }

    /// Returns black or white, whichever gives better contrast against `color`.
    ///
    /// Uses the standard luma weighting (`0.299r + 0.587g + 0.114b`); returns black for
    /// light backgrounds (`luma > 0.5`) and white for dark ones.
    ///
    /// - Parameter color: The background color to contrast against.
    public static func textColor(from color : Color) -> Color {
        let iColor = color.components
        let luma = 0.299*iColor.red + 0.587*iColor.green + 0.114*iColor.blue
        return luma > 0.5 ? Color.black : Color.white
        
        /*
        
        
        let ret = color.dlColor
            .shiftHue(by: 0.5)
            .shiftSaturation(by: -0.5)
            .shiftBrightness(by: 0.5)
        return Color(hue: ret.hue, saturation: ret.saturation, brightness: ret.brightness)
         */
    }
    
}

