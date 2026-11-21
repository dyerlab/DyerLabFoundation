//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Color.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2024.10.18.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import SwiftUI

public extension Color {

    /// The color's RGBA components in its platform color space, each in `[0, 1]`.
    ///
    /// Grayscale colors report their gray level for all three channels; colors
    /// that can't be resolved report all zeros.
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var raw: [CGFloat] = []

#if canImport(UIKit)
        raw = UIColor(self).cgColor.components ?? []
#elseif canImport(AppKit)
        raw = NSColor(self).cgColor.components ?? []
#endif
        if raw.count == 4 {
            return (raw[0], raw[1], raw[2], raw[3])
        } else if raw.count == 2 {
            // Grayscale color space: components are (gray, alpha)
            return (raw[0], raw[0], raw[0], raw[1])
        }

        return (0, 0, 0, 0)
    }

    /// The color converted to hue, saturation, brightness and alpha.
    var dlColor: DLColor {
        let components = self.components
        var hsba: (h: CGFloat, s: CGFloat, b: CGFloat, a: CGFloat) = (0, 0, 0, 0)

        #if canImport(UIKit)
        let col = UIColor(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha)
        col.getHue(&(hsba.h), saturation: &(hsba.s), brightness: &(hsba.b), alpha: &(hsba.a))

        #elseif canImport(AppKit)
        let col = NSColor(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha)
        col.getHue(&(hsba.h), saturation: &(hsba.s), brightness: &(hsba.b), alpha: &(hsba.a))
        #endif

        return DLColor(hue: hsba.h, saturation: hsba.s, brightness: hsba.b, alpha: hsba.a)
    }

#if os(macOS)
    /// The window background color.
    static let background = Color(NSColor.windowBackgroundColor)
    /// A secondary background color, for grouped content.
    static let secondaryBackground = Color(NSColor.underPageBackgroundColor)
    /// A tertiary background color, for controls and nested content.
    static let tertiaryBackground = Color(NSColor.controlBackgroundColor)
    /// The darker of the two alternating row background colors.
    static let alternativeBackgroundDark = Color(NSColor.alternatingContentBackgroundColors[1])
    /// The lighter of the two alternating row background colors.
    static let alternativeBackgroundLight = Color(NSColor.alternatingContentBackgroundColors.first!)
#else
    /// The window background color.
    static let background = Color(UIColor.systemBackground)
    /// A secondary background color, for grouped content.
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    /// A tertiary background color, for controls and nested content.
    static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
    /// The darker of the two alternating row background colors.
    static let alternativeBackgroundDark = Color(UIColor.secondarySystemBackground)
    /// The lighter of the two alternating row background colors.
    static let alternativeBackgroundLight = Color(UIColor.tertiarySystemBackground)
#endif

}
