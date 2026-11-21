//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ResultImage.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A binary image attached to an `AnalysisResult`, referenceable from its
/// Markdown body via `![alt](attachment:name)`.
public struct ResultImage: Sendable, Equatable {

    /// Matches the `name` used in the owning result's `attachment:` reference.
    public var name: String

    /// e.g. "image/png", "image/svg+xml".
    public var mimeType: String

    /// Pixel width, if known.
    public var width: Int?

    /// Pixel height, if known.
    public var height: Int?

    /// The raw image bytes.
    public var data: Data

    /// Initializes a new attached image.
    ///
    /// - Parameters:
    ///   - name: Matches the `name` used in the owning result's `attachment:` reference.
    ///   - mimeType: The image's MIME type (defaults to "image/png").
    ///   - width: Pixel width, if known.
    ///   - height: Pixel height, if known.
    ///   - data: The raw image bytes.
    public init(name: String, mimeType: String = "image/png",
                width: Int? = nil, height: Int? = nil, data: Data) {
        self.name = name
        self.mimeType = mimeType
        self.width = width
        self.height = height
        self.data = data
    }
}
