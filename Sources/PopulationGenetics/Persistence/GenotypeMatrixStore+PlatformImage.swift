//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMatrixStore+PlatformImage.swift
//  PopulationGenetics
//
//  Optional `UIImage`/`NSImage` convenience over the platform-neutral
//  `ResultImage` (Data) API in `GenotypeMatrixStore+Results.swift`. Gated by
//  `canImport` so the package still does not unconditionally import
//  UIKit/AppKit — only whichever one actually exists on the build platform.
//

import Foundation
import PresentationZen

#if canImport(UIKit)
import UIKit

extension GenotypeMatrixStore {

    /// Encodes `image` as PNG and attaches it to `resultID` under `name`.
    public func attachImage(_ image: UIImage, name: String, to resultID: UUID) async throws {
        guard let data = image.pngData() else {
            throw PersistenceError.corruptData("could not encode UIImage \"\(name)\" as PNG")
        }
        try await attachImage(ResultImage(name: name, mimeType: "image/png",
                                           width: Int(image.size.width), height: Int(image.size.height),
                                           data: data), to: resultID)
    }

    /// Decodes the image attached to `resultID` under `name`, or `nil` if none exists.
    public func uiImage(named name: String, for resultID: UUID) async throws -> UIImage? {
        guard let record = try await image(named: name, for: resultID) else { return nil }
        return UIImage(data: record.data)
    }
}

#elseif canImport(AppKit)
import AppKit

extension GenotypeMatrixStore {

    /// Encodes `image` as PNG and attaches it to `resultID` under `name`.
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
    public func nsImage(named name: String, for resultID: UUID) async throws -> NSImage? {
        guard let record = try await image(named: name, for: resultID) else { return nil }
        return NSImage(data: record.data)
    }
}
#endif
