//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TIFFImageLayout.swift
//  Matrix
//
//  How a single-band TIFF's samples are laid out (strips or tiles, bit depth,
//  sample format, compression, predictor) and how to turn one block back
//  into `Float`s. Reading block by block is what lets a crop touch only the
//  strips or tiles that overlap the study area.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The sample layout of a single-band TIFF image.
struct TIFFImageLayout {
    /// The image width in pixels.
    let width: Int
    /// The image height in pixels.
    let height: Int
    /// The width of one strip or tile, in pixels (the image width for strips).
    let blockWidth: Int
    /// The height of one strip or tile, in pixels.
    let blockHeight: Int
    /// `true` if the image is stored in tiles rather than strips.
    let isTiled: Bool
    /// The number of blocks across the image.
    let blocksAcross: Int
    /// Each block's file offset, row of blocks by row of blocks.
    let offsets: [Int]
    /// Each block's compressed size in bytes.
    let byteCounts: [Int]
    /// The bytes in one sample: 1, 2, 4 or 8.
    let bytesPerSample: Int
    /// The TIFF sample format: 1 = unsigned integer, 2 = signed integer, 3 = floating point.
    let sampleFormat: Int
    /// The TIFF compression code.
    let compression: Int
    /// The TIFF predictor: 1 = none, 2 = horizontal differencing, 3 = floating-point.
    let predictor: Int
    /// The GDAL no-data value, if the file declares one.
    let noData: Double?
    /// `true` if multi-byte samples are big-endian in the file.
    let isBigEndian: Bool

    // TIFF tags.
    static let imageWidthTag: UInt16 = 256
    static let imageLengthTag: UInt16 = 257
    static let bitsPerSampleTag: UInt16 = 258
    static let compressionTag: UInt16 = 259
    static let stripOffsetsTag: UInt16 = 273
    static let samplesPerPixelTag: UInt16 = 277
    static let rowsPerStripTag: UInt16 = 278
    static let stripByteCountsTag: UInt16 = 279
    static let predictorTag: UInt16 = 317
    static let tileWidthTag: UInt16 = 322
    static let tileLengthTag: UInt16 = 323
    static let tileOffsetsTag: UInt16 = 324
    static let tileByteCountsTag: UInt16 = 325
    static let sampleFormatTag: UInt16 = 339
    static let gdalNoDataTag: UInt16 = 42113

    /// Reads the layout from a TIFF's first directory.
    ///
    /// - Throws: ``RasterImportError/multipleBands(_:)``, ``RasterImportError/unsupportedTIFF(_:)`` or
    ///   ``RasterImportError/malformedTIFF(_:)``.
    init(tiff: TIFFFile) throws {
        guard let width = try tiff.integer(Self.imageWidthTag),
              let height = try tiff.integer(Self.imageLengthTag), width > 0, height > 0 else {
            throw RasterImportError.malformedTIFF("missing image size")
        }
        self.width = width
        self.height = height
        isBigEndian = tiff.isBigEndian

        let bands = try tiff.integer(Self.samplesPerPixelTag) ?? 1
        guard bands == 1 else { throw RasterImportError.multipleBands(bands) }

        let bits = try tiff.integer(Self.bitsPerSampleTag) ?? 1
        sampleFormat = try tiff.integer(Self.sampleFormatTag) ?? 1
        switch (sampleFormat, bits) {
        case (1, 8), (1, 16), (1, 32), (2, 8), (2, 16), (2, 32), (3, 32), (3, 64):
            bytesPerSample = bits / 8
        default:
            throw RasterImportError.unsupportedTIFF("\(bits)-bit samples of format \(sampleFormat)")
        }

        compression = try tiff.integer(Self.compressionTag) ?? 1
        guard TIFFDecompression.supportedCodes.contains(compression) else {
            throw RasterImportError.unsupportedTIFF("compression scheme \(compression)")
        }
        predictor = try tiff.integer(Self.predictorTag) ?? 1
        guard [1, 2, 3].contains(predictor) else {
            throw RasterImportError.unsupportedTIFF("predictor \(predictor)")
        }

        if let tileWidth = try tiff.integer(Self.tileWidthTag),
           let tileHeight = try tiff.integer(Self.tileLengthTag) {
            guard tileWidth > 0, tileHeight > 0,
                  let offsets = try tiff.integers(Self.tileOffsetsTag),
                  let byteCounts = try tiff.integers(Self.tileByteCountsTag) else {
                throw RasterImportError.malformedTIFF("missing tile offsets")
            }
            isTiled = true
            blockWidth = tileWidth
            blockHeight = tileHeight
            self.offsets = offsets
            self.byteCounts = byteCounts
        } else {
            guard let offsets = try tiff.integers(Self.stripOffsetsTag),
                  let byteCounts = try tiff.integers(Self.stripByteCountsTag) else {
                throw RasterImportError.malformedTIFF("missing strip offsets")
            }
            isTiled = false
            blockWidth = width
            blockHeight = min(max(try tiff.integer(Self.rowsPerStripTag) ?? height, 1), height)
            self.offsets = offsets
            self.byteCounts = byteCounts
        }
        blocksAcross = (width + blockWidth - 1) / blockWidth
        let blocksDown = (height + blockHeight - 1) / blockHeight
        guard offsets.count >= blocksAcross * blocksDown, byteCounts.count >= offsets.count else {
            throw RasterImportError.malformedTIFF("too few strip or tile offsets")
        }

        let noDataText = try tiff.string(Self.gdalNoDataTag)?.trimmingCharacters(in: .whitespaces)
        noData = noDataText.flatMap(Double.init)
    }

    /// The pixel rows block row `blockRow` covers.
    func pixelRows(ofBlockRow blockRow: Int) -> Range<Int> {
        blockRow * blockHeight ..< min((blockRow + 1) * blockHeight, height)
    }

    /// The pixel columns block column `blockCol` covers.
    func pixelCols(ofBlockCol blockCol: Int) -> Range<Int> {
        blockCol * blockWidth ..< min((blockCol + 1) * blockWidth, width)
    }

    /// Decodes one block into `Float`s, row-major, `blockWidth` per row, with no-data values as `Float.nan`.
    ///
    /// A tile always holds `blockHeight` rows, padded past the image edge; the last strip holds only the rows
    /// that remain. A block with no stored bytes (GDAL's sparse files) comes back entirely missing.
    func decodeBlock(row blockRow: Int, col blockCol: Int, reader: TIFFByteReader) throws -> [Float] {
        let index = blockRow * blocksAcross + blockCol
        let rowsInBlock = isTiled ? blockHeight : pixelRows(ofBlockRow: blockRow).count
        let sampleCount = blockWidth * rowsInBlock
        guard byteCounts[index] > 0 else { return [Float](repeating: .nan, count: sampleCount) }
        let compressed = try reader.bytes(at: offsets[index], count: byteCounts[index])
        var bytes = try TIFFDecompression.decode(compressed, compression: compression,
                                                 expectedCount: sampleCount * bytesPerSample)
        var bigEndian = isBigEndian
        switch predictor {
        case 2:
            undoHorizontalDifferencing(&bytes, rows: rowsInBlock)
        case 3:
            undoFloatingPointPredictor(&bytes, rows: rowsInBlock)
            // The floating-point predictor reassembles samples in the reader's (little-endian) order.
            bigEndian = false
        default:
            break
        }
        return samples(bytes, count: sampleCount, bigEndian: bigEndian)
    }

    // MARK: - Predictors

    /// Reverses predictor 2: each sample was stored as its difference from the one to its left.
    private func undoHorizontalDifferencing(_ bytes: inout [UInt8], rows: Int) {
        let size = bytesPerSample
        let mask: UInt64 = size == 8 ? .max : (1 << UInt64(size * 8)) - 1
        for row in 0 ..< rows {
            let rowStart = row * blockWidth * size
            var previous = readSample(bytes, at: rowStart, size: size)
            for col in 1 ..< max(blockWidth, 1) {
                let offset = rowStart + col * size
                let value = (readSample(bytes, at: offset, size: size) &+ previous) & mask
                writeSample(&bytes, value, at: offset, size: size)
                previous = value
            }
        }
    }

    /// Reverses predictor 3: each row's bytes were split into planes by significance, then byte-differenced.
    private func undoFloatingPointPredictor(_ bytes: inout [UInt8], rows: Int) {
        let size = bytesPerSample
        let rowBytes = blockWidth * size
        var shuffled = [UInt8](repeating: 0, count: rowBytes)
        for row in 0 ..< rows {
            let rowStart = row * rowBytes
            for index in 1 ..< max(rowBytes, 1) {
                bytes[rowStart + index] &+= bytes[rowStart + index - 1]
            }
            for index in 0 ..< rowBytes {
                shuffled[index] = bytes[rowStart + index]
            }
            // Plane 0 holds every sample's most significant byte; write each sample back little-endian.
            for col in 0 ..< blockWidth {
                for byte in 0 ..< size {
                    bytes[rowStart + col * size + byte] = shuffled[(size - byte - 1) * blockWidth + col]
                }
            }
        }
    }

    private func readSample(_ bytes: [UInt8], at offset: Int, size: Int) -> UInt64 {
        var value: UInt64 = 0
        for index in 0 ..< size {
            value = value << 8 | UInt64(bytes[offset + (isBigEndian ? index : size - 1 - index)])
        }
        return value
    }

    private func writeSample(_ bytes: inout [UInt8], _ value: UInt64, at offset: Int, size: Int) {
        for index in 0 ..< size {
            let shift = UInt64(8 * (isBigEndian ? size - 1 - index : index))
            bytes[offset + index] = UInt8(truncatingIfNeeded: value >> shift)
        }
    }

    // MARK: - Sample conversion

    /// Converts raw samples to `Float`, with no-data values as `Float.nan`.
    private func samples(_ bytes: [UInt8], count: Int, bigEndian: Bool) -> [Float] {
        var output = [Float](repeating: .nan, count: count)
        let size = bytesPerSample
        let noData = noData
        let noDataFloat = noData.map(Float.init)
        bytes.withUnsafeBytes { raw in
            for index in 0 ..< count {
                var bits: UInt64 = 0
                let offset = index * size
                for byte in 0 ..< size {
                    let shift = UInt64(8 * (bigEndian ? size - 1 - byte : byte))
                    bits |= UInt64(raw[offset + byte]) << shift
                }
                let value: Double
                switch (sampleFormat, size) {
                case (1, _): value = Double(bits)
                case (2, 1): value = Double(Int8(truncatingIfNeeded: bits))
                case (2, 2): value = Double(Int16(truncatingIfNeeded: bits))
                case (2, _): value = Double(Int32(truncatingIfNeeded: bits))
                case (3, 4):
                    // Compare Float32 data with the no-data value at Float precision, as GDAL does.
                    let float = Float(bitPattern: UInt32(truncatingIfNeeded: bits))
                    output[index] = float == noDataFloat ? .nan : float
                    continue
                default: value = Double(bitPattern: bits)
                }
                output[index] = value == noData ? .nan : Float(value)
            }
        }
        return output
    }
}
