//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RasterOverlay.swift
//  Graph
//
//  SwiftUI's `Map` has no image overlay, so rasters are drawn through
//  MapKit's `MKOverlay`/`MKOverlayRenderer`. MapKit draws in Web Mercator, so
//  the image is resampled onto a Mercator grid over the raster's longitude/
//  latitude bounds: each pixel takes the cell under its centre (nearest
//  neighbour, so categorical layers keep their classes). That one rule
//  handles both a geographic raster, whose rows just need Mercator spacing,
//  and a projected one (UTM, Albers), whose grid is curved on the map and
//  leaves transparent corners.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

#if !os(watchOS)
import MapKit
import Matrix

/// A raster drawn as one image over its extent on an `MKMapView`.
final class RasterOverlay: NSObject, MKOverlay {
    /// The overlay's centre.
    let coordinate: CLLocationCoordinate2D
    /// The overlay's extent in map points.
    let boundingMapRect: MKMapRect
    /// The colour-mapped raster, rows already spaced for Web Mercator.
    let image: CGImage?

    /// Builds the overlay image for a raster.
    ///
    /// - Parameters:
    ///   - raster: The raster to draw.
    ///   - colorRamp: The colours for low to high values.
    ///   - valueRange: The values at the ends of the ramp, or `nil` for the raster's own range.
    init(raster: Raster, colorRamp: RasterColorRamp, valueRange: ClosedRange<Float>?) {
        let bounds = raster.geographicBounds
        let northWest = MKMapPoint(CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.west))
        let southEast = MKMapPoint(CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.east))
        let mapRect = MKMapRect(x: northWest.x, y: northWest.y,
                                width: southEast.x - northWest.x, height: southEast.y - northWest.y)
        boundingMapRect = mapRect
        coordinate = CLLocationCoordinate2D(latitude: (bounds.north + bounds.south) / 2,
                                            longitude: (bounds.west + bounds.east) / 2)
        // About one pixel per cell. Longitude depends only on the pixel's column and latitude only on its row,
        // so each is worked out once.
        let width = raster.cols
        let height = raster.rows
        let longitudes = (0 ..< width).map { col in
            MKMapPoint(x: mapRect.minX + (Double(col) + 0.5) / Double(width) * mapRect.width, y: mapRect.midY)
                .coordinate.longitude
        }
        let latitudes = (0 ..< height).map { row in
            MKMapPoint(x: mapRect.minX, y: mapRect.minY + (Double(row) + 0.5) / Double(height) * mapRect.height)
                .coordinate.latitude
        }
        image = colorRamp.makeImage(raster: raster, valueRange: valueRange, width: width, height: height) { row, col in
            raster.cell(longitude: longitudes[col], latitude: latitudes[row]).map { $0.row * raster.cols + $0.col }
        }
    }
}

/// Draws a ``RasterOverlay``'s image into its map rectangle.
final class RasterOverlayRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? RasterOverlay, let image = overlay.image else { return }
        let rect = rect(for: overlay.boundingMapRect)
        context.saveGState()
        // Keep cells as crisp blocks when zoomed in, rather than blurring them together.
        context.interpolationQuality = .none
        // The renderer's context runs y downward, but CGImages draw bottom-up, so flip.
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }
}
#endif
