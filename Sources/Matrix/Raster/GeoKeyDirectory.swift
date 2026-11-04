//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GeoKeyDirectory.swift
//  Matrix
//
//  The GeoKey directory (OGC GeoTIFF 1.1, §7.1): a table of key entries in
//  tag 34735 whose values are stored inline (shorts), in GeoDoubleParams
//  (34736) or in GeoAsciiParams (34737, '|'-terminated strings).
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A GeoTIFF's GeoKeys, by key ID.
struct GeoKeyDirectory {
    /// Keys with short values.
    let shorts: [Int: Int]
    /// Keys with double values (the first, for keys holding several).
    let doubles: [Int: Double]
    /// Keys with text values, without the trailing `|`.
    let strings: [Int: String]

    static let directoryTag: UInt16 = 34735
    static let doubleParamsTag: UInt16 = 34736
    static let asciiParamsTag: UInt16 = 34737

    /// Reads the directory of a TIFF.
    ///
    /// - Throws: ``RasterImportError/missingGeoreference`` if there is no directory, or
    ///   ``RasterImportError/malformedTIFF(_:)`` if it's truncated.
    init(tiff: TIFFFile) throws {
        guard let directory = try tiff.integers(Self.directoryTag) else {
            throw RasterImportError.missingGeoreference
        }
        guard directory.count >= 4 else { throw RasterImportError.malformedTIFF("short GeoKey directory") }
        let keyCount = directory[3]
        guard directory.count >= 4 + keyCount * 4 else {
            throw RasterImportError.malformedTIFF("truncated GeoKey directory")
        }
        let doubleParams = try tiff.doubles(Self.doubleParamsTag) ?? []
        let asciiParams = Array(try tiff.string(Self.asciiParamsTag) ?? "")
        var shorts: [Int: Int] = [:]
        var doubles: [Int: Double] = [:]
        var strings: [Int: String] = [:]
        for index in 0 ..< keyCount {
            let entry = 4 + index * 4
            let key = directory[entry]
            let location = directory[entry + 1]
            let count = directory[entry + 2]
            let value = directory[entry + 3]
            switch Int(location) {
            case 0:
                // A location of 0 means the value is stored in the entry itself.
                shorts[key] = value
            case Int(Self.doubleParamsTag):
                if value < doubleParams.count { doubles[key] = doubleParams[value] }
            case Int(Self.asciiParamsTag):
                if value >= 0, value + count <= asciiParams.count {
                    var text = String(asciiParams[value ..< value + count])
                    if text.hasSuffix("|") { text.removeLast() }
                    strings[key] = text
                }
            default:
                // Values in other tags (rare) aren't needed.
                break
            }
        }
        self.shorts = shorts
        self.doubles = doubles
        self.strings = strings
    }
}
