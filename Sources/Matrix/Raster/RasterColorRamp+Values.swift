//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RasterColorRamp+Values.swift
//  Matrix
//
//  A ramp drawn over any grid of values, not only a raster's cells: one pixel
//  per value, as a heatmap of a distance matrix needs. Missing values (NaN)
//  are transparent.
//
//  Created by Rodney Dyer on 2026.11.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import CoreGraphics
import Foundation

public extension RasterColorRamp {

    /// Draws a grid of values as an image, one pixel per value.
    ///
    /// - Parameters:
    ///   - values: The values, row by row, `width × height` of them.
    ///   - width: The number of columns.
    ///   - height: The number of rows.
    ///   - valueRange: The values mapped to the ends of the ramp.
    /// - Returns: The image, or `nil` when the size isn't positive or doesn't match `values`.
    func makeImage(values: [Double], width: Int, height: Int, valueRange: ClosedRange<Double>) -> CGImage? {
        guard width > 0, height > 0, values.count == width * height else { return nil }
        // A 256-entry lookup table keeps per-value work to one index, which matters for a million values.
        let table: [(UInt8, UInt8, UInt8)] = (0 ..< 256).map { index in
            let color = color(at: Double(index) / 255)
            return (UInt8((color.red * 255).rounded()), UInt8((color.green * 255).rounded()),
                    UInt8((color.blue * 255).rounded()))
        }
        let span = valueRange.upperBound - valueRange.lowerBound
        var pixels = [UInt8](repeating: 0, count: values.count * 4)
        for (index, value) in values.enumerated() where !value.isNaN {
            let position = span > 0 ? (value - valueRange.lowerBound) / span : 0.5
            let (red, green, blue) = table[Int((min(max(position, 0), 1) * 255).rounded())]
            let offset = index * 4
            pixels[offset] = red
            pixels[offset + 1] = green
            pixels[offset + 2] = blue
            pixels[offset + 3] = 255
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
