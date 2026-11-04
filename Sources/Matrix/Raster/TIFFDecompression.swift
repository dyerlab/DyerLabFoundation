//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TIFFDecompression.swift
//  Matrix
//
//  The compression schemes GDAL and terra write by default: none, LZW
//  (terra's default), Deflate and PackBits. Deflate goes through Apple's
//  Compression framework, whose ZLIB codec is raw deflate, so the two-byte
//  zlib header is stripped first and the Adler-32 trailer is ignored.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Compression
import Foundation

/// Decoders for TIFF compression schemes.
enum TIFFDecompression {

    /// The TIFF compression codes this reader decodes.
    static let supportedCodes: Set<Int> = [1, 5, 8, 32773, 32946]

    /// Decompresses one strip or tile.
    ///
    /// - Parameters:
    ///   - block: The compressed bytes.
    ///   - compression: The TIFF compression code.
    ///   - expectedCount: The decompressed size in bytes. Short output is zero-padded, long output truncated.
    /// - Returns: Exactly `expectedCount` bytes.
    /// - Throws: ``RasterImportError/unsupportedTIFF(_:)`` for an unknown scheme, or
    ///   ``RasterImportError/malformedTIFF(_:)`` for corrupt data.
    static func decode(_ block: Data, compression: Int, expectedCount: Int) throws -> [UInt8] {
        var output: [UInt8]
        switch compression {
        case 1: output = [UInt8](block)
        case 5: output = try lzw(block, expectedCount: expectedCount)
        case 8, 32946: output = try deflate(block, expectedCount: expectedCount)
        case 32773: output = packBits(block, expectedCount: expectedCount)
        default: throw RasterImportError.unsupportedTIFF("compression scheme \(compression)")
        }
        if output.count < expectedCount {
            output.append(contentsOf: repeatElement(0, count: expectedCount - output.count))
        } else if output.count > expectedCount {
            output.removeLast(output.count - expectedCount)
        }
        return output
    }

    // MARK: - LZW

    /// Decodes TIFF's LZW variant: MSB-first codes of 9 to 12 bits, with the code width growing one code early.
    static func lzw(_ block: Data, expectedCount: Int) throws -> [UInt8] {
        let input = [UInt8](block)
        // Pre-TIFF 6.0 "old-style" LZW is bit-reversed; libtiff recognises it by these first bytes.
        if input.count >= 2, input[0] == 0, input[1] & 1 == 1 {
            throw RasterImportError.unsupportedTIFF("old-style LZW compression")
        }
        let clearCode = 256
        let endCode = 257
        var prefix = [Int](repeating: -1, count: 4096)
        var suffix = [UInt8](repeating: 0, count: 4096)
        var firstByte = [UInt8](repeating: 0, count: 4096)
        var length = [Int](repeating: 0, count: 4096)
        for code in 0 ..< 256 {
            suffix[code] = UInt8(code)
            firstByte[code] = UInt8(code)
            length[code] = 1
        }
        var output: [UInt8] = []
        output.reserveCapacity(expectedCount)
        var nextCode = 258
        var width = 9
        var previous = -1
        var bitBuffer: UInt32 = 0
        var bitCount = 0
        var position = 0

        func emit(_ code: Int) {
            let start = output.count
            output.append(contentsOf: repeatElement(0, count: length[code]))
            var current = code
            var index = start + length[code] - 1
            while current >= 0 {
                output[index] = suffix[current]
                index -= 1
                current = prefix[current]
            }
        }

        while output.count < expectedCount {
            while bitCount < width, position < input.count {
                bitBuffer = bitBuffer << 8 | UInt32(input[position])
                position += 1
                bitCount += 8
            }
            guard bitCount >= width else { break }
            let code = Int((bitBuffer >> UInt32(bitCount - width)) & UInt32((1 << width) - 1))
            bitCount -= width
            if code == endCode { break }
            if code == clearCode {
                nextCode = 258
                width = 9
                previous = -1
                continue
            }
            if previous < 0 {
                guard code < 256 else { throw RasterImportError.malformedTIFF("bad LZW code after a clear") }
                emit(code)
                previous = code
                continue
            }
            guard code <= nextCode, code < 4096 else {
                throw RasterImportError.malformedTIFF("bad LZW code \(code)")
            }
            // A code equal to the next free one is the string being defined right now (the KwKwK case):
            // the previous string plus its own first byte.
            let isNewCode = code == nextCode
            let addedByte = isNewCode ? firstByte[previous] : firstByte[code]
            if nextCode < 4096 {
                prefix[nextCode] = previous
                suffix[nextCode] = addedByte
                firstByte[nextCode] = firstByte[previous]
                length[nextCode] = length[previous] + 1
                nextCode += 1
            }
            emit(code)
            previous = code
            // libtiff widens codes as soon as the next code would need the extra bit ("early change").
            if nextCode >= (1 << width) - 1, width < 12 {
                width += 1
            }
        }
        return output
    }

    // MARK: - Deflate

    /// Decodes zlib-wrapped deflate data.
    static func deflate(_ block: Data, expectedCount: Int) throws -> [UInt8] {
        let input = [UInt8](block)
        guard input.count > 2, input[0] & 0x0F == 8 else {
            throw RasterImportError.malformedTIFF("bad Deflate stream header")
        }
        guard expectedCount > 0 else { return [] }
        var output = [UInt8](repeating: 0, count: expectedCount)
        let written = input.withUnsafeBufferPointer { source in
            output.withUnsafeMutableBufferPointer { destination in
                compression_decode_buffer(destination.baseAddress!, expectedCount,
                                          source.baseAddress! + 2, input.count - 2,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { throw RasterImportError.malformedTIFF("corrupt Deflate data") }
        return output
    }

    // MARK: - PackBits

    /// Decodes PackBits run-length encoding.
    static func packBits(_ block: Data, expectedCount: Int) -> [UInt8] {
        let input = [UInt8](block)
        var output: [UInt8] = []
        output.reserveCapacity(expectedCount)
        var position = 0
        while position < input.count, output.count < expectedCount {
            let header = Int(Int8(bitPattern: input[position]))
            position += 1
            if header >= 0 {
                let end = min(position + header + 1, input.count)
                output.append(contentsOf: input[position ..< end])
                position = end
            } else if header != -128, position < input.count {
                output.append(contentsOf: repeatElement(input[position], count: 1 - header))
                position += 1
            }
        }
        return output
    }
}
