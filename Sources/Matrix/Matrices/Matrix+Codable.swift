//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//
//  Created by Rodney Dyer on 4/23/26.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

// MARK: - Codable

extension Matrix: Codable {

    private enum CodingKeys: String, CodingKey {
        case values
        case rowNames
        case colNames
    }

    /// Encodes the matrix as a flat `[Double]` array plus row and column name arrays.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Array(values), forKey: .values)
        try container.encode(rowNames, forKey: .rowNames)
        try container.encode(colNames, forKey: .colNames)
    }

    /// Reconstructs a matrix from its flat value array and dimension names.
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedValues   = try container.decode([Double].self,   forKey: .values)
        let decodedRowNames = try container.decode([String].self,   forKey: .rowNames)
        let decodedColNames = try container.decode([String].self,   forKey: .colNames)
        self.init(decodedRowNames.count, decodedColNames.count, Vector(decodedValues))
        self.rowNames = decodedRowNames
        self.colNames = decodedColNames
    }

}


// MARK: - Nested-array helpers

public extension Matrix {

    /// Returns the matrix values as a row-major nested array.
    var nestedArray: [[Double]] {
        (0..<rows).map { r in (0..<cols).map { c in self[r, c] } }
    }

    /// Initialises a matrix from a row-major nested array and optional dimension names.
    ///
    /// - Parameters:
    ///   - nested: Row-major `[[Double]]` where every inner array must have the same length.
    ///   - rowNames: Names for each row (defaults to empty strings).
    ///   - colNames: Names for each column (defaults to empty strings).
    convenience init(
        nested: [[Double]],
        rowNames: [String] = [],
        colNames: [String] = []
    ) {
        let r = nested.count
        let c = nested.first?.count ?? 0
        let flat = nested.flatMap { $0 }
        self.init(r, c, Vector(flat))
        if rowNames.count == r { self.rowNames = rowNames }
        if colNames.count == c { self.colNames = colNames }
    }

}
