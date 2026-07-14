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

