//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '--| |/ _` | '_ \
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

import Matrix
import SwiftUI

// MARK: - MatrixEditorView

/// A convenience wrapper that lets you pass a `Matrix` class instance directly to a
/// `MatrixView` for in-place editing.
///
/// `MatrixEditorView` holds an internal `@State` copy of the matrix values.  Every edit
/// is written back to the original `Matrix` object immediately via `onChange`, so callers
/// observe changes through the class reference in the normal way.
///
/// ## Usage
///
/// ```swift
/// let matrix = Matrix(3, 3)
/// matrix.rowNames = ["A", "B", "C"]
/// matrix.colNames = ["A", "B", "C"]
///
/// MatrixEditorView(matrix: matrix)
/// ```
public struct MatrixEditorView: View {

    // MARK: - Properties

    private let matrix: Matrix

    @State private var values: [[Double]]

    private let adjustDiagonal: Bool

    // MARK: - Init

    /// Creates a `MatrixEditorView` wrapping a `Matrix` instance.
    ///
    /// - Parameters:
    ///   - matrix: The `Matrix` object to display and edit.
    ///   - adjustDiagonalForRowStochastic: Whether to auto-compute the diagonal on each edit.
    public init(matrix: Matrix, adjustDiagonalForRowStochastic: Bool = true) {
        self.matrix = matrix
        self.adjustDiagonal = adjustDiagonalForRowStochastic
        self._values = State(initialValue: matrix.nestedArray)
    }

    // MARK: - Body

    public var body: some View {
        MatrixView(
            values: $values,
            rowNames: matrix.rowNames,
            colNames: matrix.colNames,
            adjustDiagonalForRowStochastic: adjustDiagonal
        )
        .onChange(of: values) { _, newValues in
            for r in 0..<min(newValues.count, matrix.rows) {
                for c in 0..<min(newValues[r].count, matrix.cols) {
                    matrix[r, c] = newValues[r][c]
                }
            }
        }
    }

}

// MARK: - Previews

private func islandMatrix(k: Int, m: Double) -> Matrix {
    let names = (1...k).map { "Pop\($0)" }
    let mat = Matrix(k, k, names, names)
    for i in 0..<k {
        for j in 0..<k {
            mat[i, j] = i == j ? 1.0 - m : m / Double(k - 1)
        }
    }
    return mat
}
#if !SPM_BUILD

#Preview("3×3 island model") {
    MatrixEditorView(matrix: islandMatrix(k: 3, m: 0.1))
        .padding()
        .frame(minWidth: 380)
}

#Preview("5×5 stepping stone") {
    let k = 5
    let m = 0.05
    let names = (1...k).map { "Pop\($0)" }
    let mat = Matrix(k, k, names, names)
    for i in 0..<k {
        if i > 0     { mat[i, i-1] = m }
        if i < k-1   { mat[i, i+1] = m }
        mat[i, i] = 1.0 - mat.getRow(r: i).reduce(0, +)
    }
    return MatrixEditorView(matrix: mat, adjustDiagonalForRowStochastic: true)
        .padding()
        .frame(minWidth: 480)
}
#endif
