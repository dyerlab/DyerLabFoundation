//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Raster+Matrix.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension Raster {

    /// The cell values as a `rows × cols` ``Matrix``, northernmost row first.
    ///
    /// Missing cells stay `.nan`. The matrix holds `Double`s, so it takes twice the memory of the raster.
    ///
    /// - Returns: A new matrix of the cell values.
    public func makeMatrix() -> Matrix {
        Matrix(rows, cols, values.map(Double.init))
    }
}
