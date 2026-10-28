//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MatrixAttachment.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.07.25.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// One named, generic `Matrix` attachment together with its encoded payload —
/// the unit `saveSnapshot`/`loadSnapshot` pass for the `.matrices` component.
/// Mirrors `StoredMatrixInfo` plus the payload `matrixData(named:)` fetches
/// separately.
public struct MatrixAttachment: Sendable, Equatable {
    /// Short label for this matrix, app-defined.
    public let name: String
    /// Optional longer description.
    public let description: String?
    /// The matrix's encoded payload (typically JSON via `Matrix`'s `Codable` conformance).
    public let data: Data

    /// Initializes a new matrix attachment.
    ///
    /// - Parameters:
    ///   - name: Short label for the matrix.
    ///   - description: Optional longer description.
    ///   - data: The matrix's encoded payload.
    public init(name: String, description: String? = nil, data: Data) {
        self.name = name
        self.description = description
        self.data = data
    }
}
