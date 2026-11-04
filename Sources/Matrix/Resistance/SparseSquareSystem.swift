//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  SparseSquareSystem.swift
//  Matrix
//
//  A square, non-symmetric sparse linear system solved with Accelerate. The
//  RSP matrix I − W isn't symmetric (the reference walk is row-normalised), so
//  Cholesky doesn't apply. LU is used where the OS has it (macOS 15.5,
//  iOS 18.5, visionOS 2.5); QR, available everywhere, otherwise. One
//  factorization serves both A x = b and the transposed solves Aᵀ y = e_i.
//
//  The transposed right-hand sides are solved one column at a time. On macOS
//  27.2, a multi-column transposed solve with an LU factor got every column
//  after the first wrong on a 9-cell RSP matrix (single-column solves and QR
//  were right), so the block form isn't used.
//
//  LU factorizations are also serialised: on macOS 27.2, two LU factorizations
//  running at once on different matrices crash (QR doesn't). Accelerate
//  already spreads one factorization over the cores, so little is lost; LU is
//  still about three times faster than QR on a 360,000-cell grid.
//
//  Created by Rodney Dyer on 2026.11.04.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Accelerate
import Foundation

/// A square sparse matrix in compressed columns, ready to factor and solve.
struct SparseSquareSystem {
    /// The number of rows and columns.
    let size: Int
    /// Where each column starts in ``rowIndices``, with a final entry for the total.
    var columnStarts: [Int]
    /// The row of each stored value, increasing within a column.
    var rowIndices: [Int32]
    /// The stored values.
    var values: [Double]

    /// Factors the matrix once, then solves `A x = b` and `Aᵀ Y = B`.
    ///
    /// - Parameters:
    ///   - rightHandSide: `b`, of length ``size``.
    ///   - transposedRightHandSides: The columns of `B`, one after another (column-major), or empty.
    /// - Returns: `x` and the columns of `Y` in the same layout, or `nil` if the matrix is singular or a
    ///   solution isn't finite.
    func solve(_ rightHandSide: [Double], transposed transposedRightHandSides: [Double])
        -> (x: [Double], y: [Double])? {
        let columns = transposedRightHandSides.count / max(size, 1)
        var starts = columnStarts
        var rows = rowIndices
        var data = values
        var x = rightHandSide
        var y = transposedRightHandSides
        let solved: Bool = Self.lock.withLock { starts.withUnsafeMutableBufferPointer { startsBuffer in
            rows.withUnsafeMutableBufferPointer { rowsBuffer in
                data.withUnsafeMutableBufferPointer { dataBuffer in
                    let structure = SparseMatrixStructure(rowCount: Int32(size), columnCount: Int32(size),
                                                          columnStarts: startsBuffer.baseAddress!,
                                                          rowIndices: rowsBuffer.baseAddress!,
                                                          attributes: SparseAttributes_t(), blockSize: 1)
                    let matrix = SparseMatrix_Double(structure: structure, data: dataBuffer.baseAddress!)
                    let factor = SparseFactor(Self.factorization, matrix)
                    defer { SparseCleanup(factor) }
                    guard factor.status == SparseStatusOK else { return false }
                    x.withUnsafeMutableBufferPointer { buffer in
                        SparseSolve(factor, DenseVector_Double(count: Int32(size), data: buffer.baseAddress!))
                    }
                    let transposed = SparseGetTranspose(factor)
                    y.withUnsafeMutableBufferPointer { buffer in
                        for column in 0 ..< columns {
                            SparseSolve(transposed, DenseVector_Double(count: Int32(size),
                                                                       data: buffer.baseAddress! + column * size))
                        }
                    }
                    return true
                }
            }
        } }
        guard solved, x.allSatisfy(\.isFinite), y.allSatisfy(\.isFinite) else { return nil }
        return (x, y)
    }

    /// Serialises factorizations; see the file header.
    private static let lock = NSLock()

    /// The factorization to use: LU where available, QR otherwise.
    private static var factorization: SparseFactorization_t {
        if #available(macOS 15.5, iOS 18.5, visionOS 2.5, *) { return SparseFactorizationLU }
        return SparseFactorizationQR
    }
}
