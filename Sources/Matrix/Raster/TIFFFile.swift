//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TIFFFile.swift
//  Matrix
//
//  A minimal TIFF directory reader: the header and the first image file
//  directory (IFD), in classic TIFF or BigTIFF, either byte order. ImageIO
//  decodes TIFF pixels but drops the GeoTIFF tags and mishandles single-band
//  Float32 data, so the package reads the structure itself. Only the first
//  IFD is read: GDAL always writes the full-resolution image there, with any
//  overviews after it.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The header and first image directory of a TIFF file.
struct TIFFFile {
    /// The whole file.
    let data: Data
    /// `true` for big-endian (`MM`) files, `false` for little-endian (`II`).
    let isBigEndian: Bool
    /// The first image directory's fields, by tag.
    let fields: [UInt16: TIFFField]

    /// Parses the header and first image directory.
    ///
    /// - Parameter data: The file's bytes.
    /// - Throws: ``RasterImportError/malformedTIFF(_:)`` if the header or directory is damaged.
    init(data: Data) throws {
        self.data = data
        guard data.count >= 8 else { throw RasterImportError.malformedTIFF("file is too short") }
        let start = data.startIndex
        switch (data[start], data[start + 1]) {
        case (0x49, 0x49): isBigEndian = false
        case (0x4D, 0x4D): isBigEndian = true
        default: throw RasterImportError.malformedTIFF("missing byte-order mark")
        }
        let reader = TIFFByteReader(data: data, isBigEndian: isBigEndian)
        let isBigTIFF: Bool
        switch try reader.unsigned(at: 2, size: 2) {
        case 42: isBigTIFF = false
        case 43: isBigTIFF = true
        default: throw RasterImportError.malformedTIFF("not a TIFF file")
        }
        let directoryOffset = isBigTIFF ? try reader.offset(at: 8, size: 8) : try reader.offset(at: 4, size: 4)
        fields = try Self.readDirectory(at: directoryOffset, isBigTIFF: isBigTIFF, reader: reader)
    }

    /// A reader for this file's bytes in its byte order.
    var reader: TIFFByteReader { TIFFByteReader(data: data, isBigEndian: isBigEndian) }

    /// A field's values as integers.
    ///
    /// - Parameter tag: The field's tag.
    /// - Returns: The values, or `nil` if the field is absent or isn't an integer type.
    func integers(_ tag: UInt16) throws -> [Int]? {
        guard let field = fields[tag] else { return nil }
        return try field.integers(reader: reader)
    }

    /// A field's single integer value.
    ///
    /// - Parameter tag: The field's tag.
    /// - Returns: The first value, or `nil` if the field is absent or isn't an integer type.
    func integer(_ tag: UInt16) throws -> Int? {
        try integers(tag)?.first
    }

    /// A field's values as doubles.
    ///
    /// - Parameter tag: The field's tag.
    /// - Returns: The values, or `nil` if the field is absent or isn't numeric.
    func doubles(_ tag: UInt16) throws -> [Double]? {
        guard let field = fields[tag] else { return nil }
        return try field.doubles(reader: reader)
    }

    /// A field's ASCII value, without its trailing NUL.
    ///
    /// - Parameter tag: The field's tag.
    /// - Returns: The string, or `nil` if the field is absent or isn't ASCII.
    func string(_ tag: UInt16) throws -> String? {
        guard let field = fields[tag], field.type == 2 else { return nil }
        let bytes = try reader.bytes(at: field.valueOffset, count: field.count)
        return String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }

    private static func readDirectory(at offset: Int, isBigTIFF: Bool,
                                      reader: TIFFByteReader) throws -> [UInt16: TIFFField] {
        let countSize = isBigTIFF ? 8 : 2
        let entrySize = isBigTIFF ? 20 : 12
        let valueFieldSize = isBigTIFF ? 8 : 4
        let entryCount = try reader.offset(at: offset, size: countSize)
        var fields: [UInt16: TIFFField] = [:]
        for index in 0 ..< entryCount {
            let entry = offset + countSize + index * entrySize
            let tag = UInt16(try reader.unsigned(at: entry, size: 2))
            let type = UInt16(try reader.unsigned(at: entry + 2, size: 2))
            let count = try reader.offset(at: entry + 4, size: valueFieldSize)
            // Unknown types can't be sized; skip them rather than reject the file.
            guard let typeSize = TIFFField.size(ofType: type) else { continue }
            let valueField = entry + 4 + valueFieldSize
            let (byteCount, overflow) = count.multipliedReportingOverflow(by: typeSize)
            guard !overflow else { throw RasterImportError.malformedTIFF("tag \(tag) is too large") }
            // Values that fit in the entry's value field are stored inline; others sit at an offset.
            let valueOffset = byteCount <= valueFieldSize
                ? valueField
                : try reader.offset(at: valueField, size: valueFieldSize)
            fields[tag] = TIFFField(type: type, count: count, valueOffset: valueOffset)
        }
        return fields
    }
}

// MARK: - TIFFField

/// One directory entry: its type, value count and where its values are.
struct TIFFField {
    /// The TIFF field type (1 = BYTE, 3 = SHORT, 4 = LONG, 12 = DOUBLE, 16 = LONG8, ...).
    let type: UInt16
    /// The number of values.
    let count: Int
    /// The byte offset of the first value in the file.
    let valueOffset: Int

    /// The size in bytes of one value of a field type, or `nil` for an unknown type.
    static func size(ofType type: UInt16) -> Int? {
        switch type {
        case 1, 2, 6, 7: 1
        case 3, 8: 2
        case 4, 9, 11, 13: 4
        case 5, 10, 12, 16, 17, 18: 8
        default: nil
        }
    }

    /// The values as integers, or `nil` if this isn't an integer type.
    func integers(reader: TIFFByteReader) throws -> [Int]? {
        guard let size = Self.size(ofType: type) else { return nil }
        let isSigned: Bool
        switch type {
        case 1, 3, 4, 13, 16, 18: isSigned = false
        case 6, 8, 9, 17: isSigned = true
        default: return nil
        }
        return try (0 ..< count).map { index in
            let raw = try reader.unsigned(at: valueOffset + index * size, size: size)
            guard isSigned else { return Int(truncatingIfNeeded: raw) }
            // Sign-extend from the field's width.
            let shift = UInt64(64 - size * 8)
            return Int(Int64(bitPattern: raw << shift) >> Int64(shift))
        }
    }

    /// The values as doubles, or `nil` if this isn't a numeric type.
    func doubles(reader: TIFFByteReader) throws -> [Double]? {
        switch type {
        case 11:
            return try (0 ..< count).map {
                Double(Float(bitPattern: UInt32(try reader.unsigned(at: valueOffset + $0 * 4, size: 4))))
            }
        case 12:
            return try (0 ..< count).map {
                Double(bitPattern: try reader.unsigned(at: valueOffset + $0 * 8, size: 8))
            }
        case 5:
            return try (0 ..< count).map {
                let numerator = Double(try reader.unsigned(at: valueOffset + $0 * 8, size: 4))
                let denominator = Double(try reader.unsigned(at: valueOffset + $0 * 8 + 4, size: 4))
                return numerator / denominator
            }
        default:
            return try integers(reader: reader)?.map(Double.init)
        }
    }
}

// MARK: - TIFFByteReader

/// Bounds-checked reads of unsigned integers and byte ranges in a file's byte order.
struct TIFFByteReader {
    /// The bytes being read.
    let data: Data
    /// `true` if multi-byte values are big-endian.
    let isBigEndian: Bool

    /// An unsigned integer of `size` bytes (1, 2, 4 or 8) at a file offset.
    func unsigned(at offset: Int, size: Int) throws -> UInt64 {
        guard offset >= 0, size <= data.count, offset <= data.count - size else {
            throw RasterImportError.malformedTIFF("read past the end of the file")
        }
        let start = data.startIndex + offset
        var value: UInt64 = 0
        for index in 0 ..< size {
            let byte = UInt64(data[start + (isBigEndian ? index : size - 1 - index)])
            value = value << 8 | byte
        }
        return value
    }

    /// An unsigned integer used as an offset or count, rejected if it doesn't fit in `Int`.
    func offset(at offset: Int, size: Int) throws -> Int {
        let value = try unsigned(at: offset, size: size)
        guard value <= UInt64(Int.max) else { throw RasterImportError.malformedTIFF("offset out of range") }
        return Int(value)
    }

    /// `count` bytes starting at a file offset.
    func bytes(at offset: Int, count: Int) throws -> Data {
        guard offset >= 0, count >= 0, offset <= data.count - count else {
            throw RasterImportError.malformedTIFF("data block runs past the end of the file")
        }
        let start = data.startIndex + offset
        return data[start ..< start + count]
    }
}
