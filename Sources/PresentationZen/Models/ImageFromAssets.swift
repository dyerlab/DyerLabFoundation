//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  ImageFromAssets.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 4/18/25.
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
@available(macOS 13.0, iOS 16.0, *)
@MainActor
public func LoadFromAsset(named name: String) -> Media? {
    let image = Image(name)
    let renderer = ImageRenderer(content: image)

    guard let cgImage = renderer.cgImage else {
        print("Failed to create CGImage")
        return nil
    }

    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
        return nil
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        return nil
    }
    
    return Media(imageData: (data as Data) )
}


