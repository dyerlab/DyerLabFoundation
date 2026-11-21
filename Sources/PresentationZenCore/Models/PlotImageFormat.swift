//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PlotImageFormat.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import CoreGraphics

/// The size and resolution of a rendered chart.
public struct PlotImageFormat: Hashable, Sendable {
    /// The layout size, in points.
    public var size: CGSize
    /// The pixels per point.
    public var scale: CGFloat
    /// The margin around the chart, in points.
    public var padding: CGFloat

    /// A publication-resolution figure: 2400 pixels wide, 8 inches at 300 dpi.
    public static let figure = PlotImageFormat(size: CGSize(width: 800, height: 533), scale: 3)
    /// A small picture for a list, shown at about half size.
    public static let thumbnail = PlotImageFormat(size: CGSize(width: 480, height: 320), scale: 1)

    /// Creates a format.
    ///
    /// - Parameters:
    ///   - size: The layout size, in points.
    ///   - scale: The pixels per point.
    ///   - padding: The margin around the chart, in points.
    public init(size: CGSize, scale: CGFloat = 1, padding: CGFloat = 16) {
        self.size = size
        self.scale = scale
        self.padding = padding
    }
}
