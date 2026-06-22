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


public struct DLColor {
    
    public let hue: CGFloat
    public let saturation: CGFloat
    public let brightness: CGFloat
    public let alpha: CGFloat
    
    public init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.alpha = alpha
    }
        
    private func shift(_ value: CGFloat, by amount: CGFloat) -> CGFloat {
        return abs((value + amount).truncatingRemainder(dividingBy: 1) )
    }
    
    public func shiftHue(by amount : CGFloat) -> DLColor {
        return DLColor(hue: shift(hue, by: amount),
                        saturation: saturation,
                        brightness: brightness, alpha: alpha)
    }
    public func shiftBrightness(by amount : CGFloat) -> DLColor {
        return DLColor(hue: hue, saturation: saturation,
                        brightness: shift(brightness, by: amount), alpha: alpha)
    }
    
    public func shiftSaturation(by amount : CGFloat) -> DLColor {
        return DLColor(hue: hue, saturation: shift(saturation, by: amount),
                        brightness: brightness, alpha: alpha)
    }
    
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

