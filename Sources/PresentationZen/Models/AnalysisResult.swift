//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  AnalysisResult.swift
//  DyerLabFoundation
//
//  A human-readable analysis record (a statistical test writeup, a
//  permutation-test summary, construction notes, ...) stored as Markdown
//  alongside the data that produced it. Deliberately generic — the app
//  defines its own naming/categorization conventions, not the library.
//

import Foundation

/// A Markdown analysis record persisted alongside a project's data.
public struct AnalysisResult: Sendable, Identifiable, Equatable {

    /// Unique identifier for this result.
    public var id: UUID

    /// Short label for this result, app-defined.
    public var name: String

    /// Optional longer description.
    public var description: String?

    /// The result body, in Markdown. May reference attached images using
    /// `attachment:<name>` syntax (see `ResultImage`), the same convention
    /// Jupyter notebooks use for cell-attached images.
    public var body: String

    /// When this result was created.
    public var createdAt: Date

    /// Initializes a new analysis result.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new `UUID`).
    ///   - name: Short label for this result.
    ///   - description: Optional longer description.
    ///   - body: The result body, in Markdown.
    ///   - createdAt: When this result was created (defaults to now).
    public init(id: UUID = UUID(), name: String, description: String? = nil,
                body: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.body = body
        self.createdAt = createdAt
    }
}

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
