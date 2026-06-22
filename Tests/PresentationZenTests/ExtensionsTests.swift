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

@Suite("Array<DataPoint>.collapseByYear")
struct CollapseByYearTests {

    @Test("sums yValues within the same year and produces one entry per year")
    func sameYearSum() {
        var c = DateComponents()
        c.month = 7; c.day = 1
        c.year = 2024
        let jul2024 = Calendar.current.date(from: c)!
        c.month = 10
        let oct2024 = Calendar.current.date(from: c)!
        c.year = 2025; c.month = 3
        let mar2025 = Calendar.current.date(from: c)!

        let pts = [
            DataPoint(time: jul2024, value: 10.0),
            DataPoint(time: oct2024, value: 5.0),
            DataPoint(time: mar2025, value: 7.0),
        ]
        let result = pts.collapseByYear.sorted()
        #expect(result.count == 2)
        #expect(result[0].xValue == 2024)
        #expect(result[0].yValue == 15.0)
        #expect(result[1].xValue == 2025)
        #expect(result[1].yValue == 7.0)
    }

    @Test("silently drops points that have no date")
    func dropsUndatedPoints() {
        var c = DateComponents()
        c.year = 2024; c.month = 6; c.day = 1
        let jun2024 = Calendar.current.date(from: c)!

        let pts = [
            DataPoint(time: jun2024, value: 3.0),
            DataPoint(x: 100, y: 99),           // no date — must be dropped
        ]
        #expect(pts.collapseByYear.count == 1)
    }

    @Test("returns empty for empty input")
    func emptyInput() {
        #expect([DataPoint]().collapseByYear.isEmpty)
    }
}

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
        // abs((0.9 + 0.2) % 1) = abs(0.1) = 0.1
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

    @Test("Color.components handles grayscale (2-component) colors")
    func grayscaleComponents() {
        // System palette colors like .black/.white use a grayscale color space.
        // Before the fix they returned (0,0,0,0); now they should reflect the gray value.
        let white = Color.white
        let comps = white.components
        let luma = 0.299 * comps.red + 0.587 * comps.green + 0.114 * comps.blue
        #expect(luma > 0.5)   // white → luma near 1.0, should pick black text

        let black = Color.black
        let blackComps = black.components
        let blackLuma = 0.299 * blackComps.red + 0.587 * blackComps.green + 0.114 * blackComps.blue
        #expect(blackLuma < 0.5)   // black → luma near 0.0, should pick white text
    }
}
