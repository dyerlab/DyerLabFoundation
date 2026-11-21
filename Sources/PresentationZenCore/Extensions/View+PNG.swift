//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  View+PNG.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import ImageIO
import SwiftUI
import UniformTypeIdentifiers

public extension View {

    /// Renders the view, typically a chart, to a PNG.
    ///
    /// Images always use the light appearance on a white background, since a figure in a manuscript shouldn't
    /// depend on whether its author uses dark mode. The encoding uses ImageIO, so this works the same on every
    /// platform.
    ///
    /// - Parameter format: The image's size and resolution.
    /// - Returns: PNG data, or `nil` if the view can't be rendered.
    func pngData(_ format: PlotImageFormat = .figure) -> Data? {
        let content = padding(format.padding)
            .frame(width: format.size.width, height: format.size.height)
            .background(.white)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = format.scale
        guard let image = renderer.cgImage else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
