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
//  ExtensionsTests.swift
//
//
//  Created by Rodney Dyer on 2026-02-24.
//

import Foundation
import SwiftUI
import Testing
@testable import PresentationZen

@Suite("Date.mdy")
struct DateMdyTests {

    @Test("parses valid MM/dd/yyyy string")
    func validParse() throws {
        let d = try #require(Date.mdy("07/04/2024"))
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: d)
        #expect(comps.year == 2024)
        #expect(comps.month == 7)
        #expect(comps.day == 4)
    }

    @Test("returns nil for invalid input")
    func invalidInput() {
        #expect(Date.mdy("not-a-date") == nil)
    }

    @Test("returns nil for wrong format")
    func wrongFormat() {
        #expect(Date.mdy("2024-07-04") == nil)   // ISO format, not MM/dd/yyyy
    }
}

@Suite("DLColor")
struct DLColorTests {

    @Test("shiftHue wraps past 1.0 back to near 0")
    func hueWrapAround() {
        let c = DLColor(hue: 0.9, saturation: 0.8, brightness: 0.7, alpha: 1.0)
        let shifted = c.shiftHue(by: 0.2)
        #expect(abs(shifted.hue - 0.1) < 0.001)
        #expect(shifted.saturation == c.saturation)
        #expect(shifted.brightness == c.brightness)
    }

    @Test("shiftBrightness wraps past 1.0")
    func brightnessWrapAround() {
        let c = DLColor(hue: 0.5, saturation: 0.8, brightness: 0.9, alpha: 1.0)
        let shifted = c.shiftBrightness(by: 0.2)
        #expect(abs(shifted.brightness - 0.1) < 0.001)
    }

    @Test("shiftSaturation wraps past 1.0")
    func saturationWrapAround() {
        let c = DLColor(hue: 0.5, saturation: 0.9, brightness: 0.7, alpha: 1.0)
        let shifted = c.shiftSaturation(by: 0.2)
        #expect(abs(shifted.saturation - 0.1) < 0.001)
    }

    @Test("shifting by 0 leaves color unchanged")
    func shiftByZero() {
        let c = DLColor(hue: 0.4, saturation: 0.6, brightness: 0.8, alpha: 1.0)
        #expect(c.shiftHue(by: 0).hue == c.hue)
        #expect(c.shiftBrightness(by: 0).brightness == c.brightness)
        #expect(c.shiftSaturation(by: 0).saturation == c.saturation)
    }

    @Test("textColor returns black for light color")
    func textColorLight() {
        let light = Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1.0)
        #expect(DLColor.textColor(from: light) == Color.black)
    }

    @Test("textColor returns white for dark color")
    func textColorDark() {
        let dark = Color(red: 0.1, green: 0.1, blue: 0.1, opacity: 1.0)
        #expect(DLColor.textColor(from: dark) == Color.white)
    }

    @Test("hex initializer parses 6-digit RRGGBB")
    func hexSixDigit() throws {
        let c = try #require(DLColor(hex: "#FF0000"))
        #expect(abs(c.hue - 0.0) < 0.001)
        #expect(abs(c.saturation - 1.0) < 0.001)
        #expect(abs(c.brightness - 1.0) < 0.001)
        #expect(c.alpha == 1.0)
    }

    @Test("hex initializer parses without leading #")
    func hexNoHash() throws {
        let c = try #require(DLColor(hex: "00FF00"))
        #expect(abs(c.hue - 1.0/3.0) < 0.001)
    }

    @Test("hex initializer parses 3-digit shorthand")
    func hexThreeDigit() throws {
        let short = try #require(DLColor(hex: "#F00"))
        let long = try #require(DLColor(hex: "#FF0000"))
        #expect(abs(short.hue - long.hue) < 0.001)
        #expect(abs(short.saturation - long.saturation) < 0.001)
        #expect(abs(short.brightness - long.brightness) < 0.001)
    }

    @Test("hex initializer parses 8-digit RRGGBBAA alpha")
    func hexEightDigit() throws {
        let c = try #require(DLColor(hex: "#0000FF80"))
        #expect(abs(c.alpha - 128.0/255.0) < 0.001)
    }

    @Test("hex initializer returns nil for invalid input")
    func hexInvalid() {
        #expect(DLColor(hex: "not-a-color") == nil)
        #expect(DLColor(hex: "#12345") == nil)
    }

    @Test("Color.components handles grayscale (2-component) colors")
    func grayscaleComponents() {
        let white = Color.white
        let comps = white.components
        let luma = 0.299 * comps.red + 0.587 * comps.green + 0.114 * comps.blue
        #expect(luma > 0.5)

        let black = Color.black
        let blackComps = black.components
        let blackLuma = 0.299 * blackComps.red + 0.587 * blackComps.green + 0.114 * blackComps.blue
        #expect(blackLuma < 0.5)
    }
}
