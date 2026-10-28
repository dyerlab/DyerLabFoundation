//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectStore+PlatformImage.swift
//  PopulationGenetics
//
//  Optional `UIImage`/`NSImage` convenience over the platform-neutral
//  `ResultImage` (Data) API in `ProjectStore+Results.swift`. Gated by
//  `canImport` so the package still does not unconditionally import
//  UIKit/AppKit — only whichever one actually exists on the build platform.
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen

#if canImport(UIKit)
import UIKit

extension ProjectStore {

    /// Encodes `image` as PNG and attaches it to `resultID` under `name`.
    ///
    /// - Parameters:
    ///   - image: The image to attach.
    ///   - name: The `attachment:` name, unique per result.
    ///   - resultID: The result to attach it to.
    /// - Throws: ``PersistenceError/corruptData(_:)`` if PNG encoding fails, otherwise the errors of
    ///   ``attachImage(_:to:)``.
    public func attachImage(_ image: UIImage, name: String, to resultID: UUID) async throws {
        guard let data = image.pngData() else {
            throw PersistenceError.corruptData("could not encode UIImage \"\(name)\" as PNG")
        }
        try await attachImage(ResultImage(name: name, mimeType: "image/png",
                                           width: Int(image.size.width), height: Int(image.size.height),
                                           data: data), to: resultID)
    }

    /// Decodes the image attached to `resultID` under `name`, or `nil` if none exists.
    ///
    /// - Parameters:
    ///   - name: The `attachment:` name.
    ///   - resultID: The result the image is attached to.
    /// - Returns: The image, or `nil`.
    /// - Throws: The errors of ``image(named:for:)``.
    public func uiImage(named name: String, for resultID: UUID) async throws -> UIImage? {
        guard let record = try await image(named: name, for: resultID) else { return nil }
        return UIImage(data: record.data)
    }
}

#elseif canImport(AppKit)
import AppKit

extension ProjectStore {

    /// Encodes `image` as PNG and attaches it to `resultID` under `name`.
    ///
    /// - Parameters:
    ///   - image: The image to attach.
    ///   - name: The `attachment:` name, unique per result.
    ///   - resultID: The result to attach it to.
    /// - Throws: ``PersistenceError/corruptData(_:)`` if PNG encoding fails, otherwise the errors of
    ///   ``attachImage(_:to:)``.
    public func attachImage(_ image: NSImage, name: String, to resultID: UUID) async throws {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw PersistenceError.corruptData("could not encode NSImage \"\(name)\" as PNG")
        }
        try await attachImage(ResultImage(name: name, mimeType: "image/png",
                                           width: Int(image.size.width), height: Int(image.size.height),
                                           data: data), to: resultID)
    }

    /// Decodes the image attached to `resultID` under `name`, or `nil` if none exists.
    ///
    /// - Parameters:
    ///   - name: The `attachment:` name.
    ///   - resultID: The result the image is attached to.
    /// - Returns: The image, or `nil`.
    /// - Throws: The errors of ``image(named:for:)``.
    public func nsImage(named name: String, for resultID: UUID) async throws -> NSImage? {
        guard let record = try await image(named: name, for: resultID) else { return nil }
        return NSImage(data: record.data)
    }
}
#endif
