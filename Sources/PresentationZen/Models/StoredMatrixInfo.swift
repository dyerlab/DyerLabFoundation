//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  StoredMatrixInfo.swift
//  DyerLabFoundation
//
//  Metadata for a named `Matrix` attached to a project (a derived Fst
//  distance matrix, PCA loadings, ...) — distinct from a genetic marker
//  matrix. `Matrix` (from the `Matrix` target) is a mutable, non-`Sendable`
//  class, so it never crosses into `ProjectStore`'s actor isolation directly;
//  the payload is fetched/stored separately as `Data` (via `Matrix`'s
//  existing `Codable` conformance) and only this metadata travels with it.
//  Sits next to `AnalysisResult`, whose shape this mirrors minus a body.
//

import Foundation

/// Metadata for a named `Matrix` attached to a project. The matrix payload
/// itself is fetched/stored separately as `Data`.
public struct StoredMatrixInfo: Sendable, Identifiable, Equatable {

    /// Unique identifier for this matrix.
    public var id: UUID

    /// Short label for this matrix, app-defined.
    public var name: String

    /// Optional longer description.
    public var description: String?

    /// When this matrix was stored.
    public var createdAt: Date

    /// Initializes new matrix metadata.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new `UUID`).
    ///   - name: Short label for this matrix.
    ///   - description: Optional longer description.
    ///   - createdAt: When this matrix was stored (defaults to now).
    public init(id: UUID = UUID(), name: String, description: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
    }
}
