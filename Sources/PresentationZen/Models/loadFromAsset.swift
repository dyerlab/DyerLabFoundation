//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  loadFromAsset.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2025.04.18.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import ImageIO

/// Loads an image from the app's asset catalog and wraps it in a `Media` object.
///
/// Renders the named image using `ImageRenderer` and encodes the result as PNG data.
/// Returns `nil` if the asset is not found or the render/encode step fails.
///
/// - Parameter name: The asset catalog name of the image to load.
/// - Returns: A `Media` containing the PNG-encoded image data, or `nil` on failure.
@MainActor
public func loadFromAsset(named name: String) -> Media? {
    let image = Image(name)
    let renderer = ImageRenderer(content: image)

    guard let cgImage = renderer.cgImage else { return nil }

    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
        return nil
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        return nil
    }

    return Media(imageData: (data as Data))
}
