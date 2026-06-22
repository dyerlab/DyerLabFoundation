//
//  Matrix.swift
//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//
//  Created by Rodney Dyer on 6/10/21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//



import Foundation
import Accelerate

/// A row-major matrix class for 2-dimensional numerical data.
///
/// `Matrix` provides a performant container for 2D arrays of `Double` values, leveraging Apple's
/// Accelerate framework for optimized linear algebra operations. All matrices use row-major storage
/// internally.
///
/// ## Creating Matrices
///
/// ```swift
/// // Create a 3x3 matrix filled with zeros
/// let M = Matrix(3, 3)
///
/// // Create from a vector of values (filled row by row)
/// let values = Vector([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
/// let M2 = Matrix(2, 3, values)
///
/// // Create from a range
/// let M3 = Matrix(2, 2, 1.0...4.0)
/// ```
///
/// ## Accessing Elements
///
/// ```swift
/// let value = M[row, col]  // Get element
/// M[row, col] = 5.0        // Set element
/// ```
///
/// ## Matrix Operations
///
/// Supports standard mathematical operations including:
/// - Element-wise operations: `+`, `-`, `*`, `/`
/// - Matrix multiplication: `.*`
/// - Transpose, diagonal, trace
/// - Row and column extraction
///
/// - Note: Accessing elements outside matrix bounds returns `.nan` for reads and is ignored for writes.
/// - Important: This class uses **row-major** storage. When interfacing with column-major libraries
///   (like LAPACK), operations automatically handle transposition.
public final class Matrix {
    
    /// The storage for the values in the matrix
    var values: Vector
    
    /// The number of rows in the matrix
    public var rows: Int {
        return rowNames.count
    }
    
    /// The number of columns in the matrix
    public var cols: Int {
        return colNames.count
    }
    
    /// The Row Cames
    public var rowNames: [String]
    
    /// The Column Names
    public var colNames: [String]
    
    /// Grab the diagonal of the matrix
    public var diagonal: Vector {
        get {
            let mn = min( rows, cols)
            var ret = Vector(repeating: .nan, count: mn)
            for i in 0 ..< mn {
                ret[i] = values[ (i * cols ) + i ]
            }
            return ret
        }
        set {
            let mx = min( min( self.rows, self.cols), newValue.count )
            for i in 0 ..< mx {
                self[i,i] = newValue[i]
            }
        }
    }
    
    /// Matrix Trace
    public var trace: Double {
        get {
            return self.diagonal.sum
        }
    }
    
    /// Grab the sum of the entire matrix
    public var sum: Double {
        get {
            return self.values.sum
        }
    }
    
    /// Return the sum of the rows
    public var rowSum: Vector {
        get {
            let ones = Matrix(cols, 1, 1.0 )
            let V = self .* ones
            return V.values
        }
    }
    
    
    /// Returns sum of columns
    public var colSum: Vector {
        get {
            let ones = Matrix(1, rows, 1.0 )
            let V = ones .* self
            return V.values
        }
    }
    
    /// Returns matrix of rowsums, for colsums take transpose first
    public var rowMatrix: Matrix {
        get {
            let v = self.rowSum
            let X = Matrix( self.rows, self.cols )
            for i in 0 ..< self.rows {
                for j in 0 ..< self.cols {
                    X[i,j] = v[j]
                }
            }
            return X
        }
    }
    
    /// Returns matrix as covariance type
    public var asCovariance: Matrix {
        get {
            let K = Double( self.rows )
            let D1: Matrix = self.rowMatrix.transpose
            let D2: Matrix = self.rowMatrix
            let D: Matrix =  (D1 + D2 ) / K
            let rhs = self.sum / pow( K, 2.0 )
            return (self * -1.0 + D - rhs) * 0.5
        }
    }
    
    /// Converts from covariance to distance
    public var asDistance: Matrix {
        get {
            let K = self.rows
            let D = Matrix(K, K, 0.0 )
            for i in 0 ..< K {
                for j in 0 ..< K {
                    D[i,j] = self[i,i] + self[j,j] - self[i,j] * 2.0
                }
            }
            return D
        }
    }
    
    /// The tanspose of the matrix
    public var transpose: Matrix {
        get {
            let ret = Matrix( cols, rows, 0.0)
            vDSP_mtransD( values, 1, &ret.values, 1, vDSP_Length(cols), vDSP_Length(rows) )
            return ret
        }
    }
    
    
    
    /// Accesses the element at the specified row and column.
    ///
    /// Uses zero-based indexing with row-major storage internally.
    ///
    /// - Parameters:
    ///   - r: The row index (0-based)
    ///   - c: The column index (0-based)
    /// - Returns: The value at position `[r, c]`, or `.nan` if indices are out of bounds
    ///
    /// Setting a value at out-of-bounds indices is silently ignored.
    ///
    /// ## Example
    /// ```swift
    /// let M = Matrix(3, 3, 1.0)
    /// let value = M[0, 1]  // Returns 1.0
    /// M[1, 2] = 5.0        // Sets element at row 1, col 2 to 5.0
    /// M[10, 10] = 99.0     // Silently ignored (out of bounds)
    /// let oob = M[10, 10]  // Returns .nan
    /// ```
    public subscript(_ r: Int, _ c: Int) -> Double {
        get {
            if !areValidIndices(r, c) {
                return .nan
            }
            return values[ (r * cols) + c ]
        }
        set {
            if areValidIndices( r, c) {
                values[ (r * cols)+c ] = newValue
            }
        }
    }
    
    /// Creates a matrix filled with a constant value.
    ///
    /// - Parameters:
    ///   - r: Number of rows
    ///   - c: Number of columns
    ///   - value: Value to fill all elements (default: 0.0)
    ///
    /// ## Example
    /// ```swift
    /// let zeros = Matrix(3, 3)        // 3x3 matrix of zeros
    /// let ones = Matrix(2, 4, 1.0)    // 2x4 matrix of ones
    /// ```
    public init(_ r: Int, _ c: Int, _ value: Double = 0.0 ) {
        values  = Vector(repeating: value, count: r*c)
        rowNames = Array(repeating: "", count: r )
        colNames = Array( repeating: "", count: c )
    }
    
    /// Creates a matrix from a vector of values filled row-by-row.
    ///
    /// Values are filled in row-major order. To fill column-by-column, create the matrix
    /// and then call `.transpose`.
    ///
    /// - Parameters:
    ///   - r: Number of rows
    ///   - c: Number of columns
    ///   - vec: Vector of values (must have exactly `r * c` elements)
    ///
    /// If `vec.count ≠ r * c`, creates an empty matrix.
    ///
    /// ## Example
    /// ```swift
    /// let values = Vector([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
    /// let M = Matrix(2, 3, values)
    /// // Results in:
    /// // [1.0, 2.0, 3.0]
    /// // [4.0, 5.0, 6.0]
    /// ```
    public init(_ r: Int, _ c: Int, _ vec: Vector) {
        if vec.count == 0 || r*c != vec.count {
            // On a size mismatch, produce a consistent empty (0×0) matrix.
            // `rows`/`cols` are derived from the name arrays, so leaving them
            // sized r/c while `values` is empty would report full dimensions
            // backed by an empty buffer and crash on the first in-bounds read.
            values = [Double]()
            rowNames = []
            colNames = []
        } else  {
            self.values = vec
            rowNames = Array(repeating: "", count: r )
            colNames = Array( repeating: "", count: c )
        }
    }

    public init(_ r: Int, _ c: Int, _ seq: ClosedRange<Double>) {
        let count = r * c
        if count <= 0 {
            values = []
            rowNames = []
            colNames = []
            return
        }
        if count == 1 {
            // A single element cannot span a range; use the lower bound.
            values = [seq.lowerBound]
        } else {
            // Build exactly `count` evenly spaced values; index-based mapping
            // guarantees the element count (floating-point stride can be off by
            // one) and pins the final value to the exact upper bound.
            let unit = (seq.upperBound - seq.lowerBound) / Double(count - 1)
            var vec = (0..<count).map { seq.lowerBound + Double($0) * unit }
            vec[count - 1] = seq.upperBound
            values = vec
        }
        rowNames = Array(repeating: "", count: r )
        colNames = Array( repeating: "", count: c )
    }
    
    public init(_ r: Int, _ c: Int, _ rowNames: [String], _ colNames: [String] ) {
        self.values  = Vector(repeating: 0.0, count: r*c)
        self.rowNames = rowNames
        self.colNames = colNames
    }
    
    
    
    /// Extracts a row as a vector.
    ///
    /// - Parameter r: The row index (0-based)
    /// - Returns: A vector containing all elements in the specified row
    public func getRow( r: Int) -> Vector {
        var ret = Vector(repeating: 0.0, count: self.cols )
        for c in 0 ..< self.cols {
            ret[c] = self[r,c]
        }
        return ret
    }
    
    /// Extracts a column as a vector.
    ///
    /// - Parameter c: The column index (0-based)
    /// - Returns: A vector containing all elements in the specified column
    public func getCol( c: Int ) -> Vector {
        var ret = Vector( repeating: 0.0, count: self.rows )
        for r in 0 ..< self.rows {
            ret[r] = self[r,c]
        }
        return ret
    }
    
    
    /// An internal function to check the indices to see if they will work properly
    internal func areValidIndices(_ r: Int, _ c: Int ) -> Bool {
        return r >= 0 && c >= 0 && r < rows && c < cols
    }
    
}


// MARK: - Protocols

extension Matrix: Equatable {
    
    /// Equality Operator overload
    /// - Parameters:
    ///   - lhs: The left matrix
    ///   - rhs: The right matrix
    /// - Returns: Returns a `Bool` indicating element-wise equality and shape of the two matrices
    public static func ==(lhs: Matrix, rhs: Matrix) -> Bool {
        return lhs.values == rhs.values &&
        lhs.rows == rhs.rows &&
        lhs.cols == rhs.cols &&
        lhs.rowNames == rhs.rowNames &&
        lhs.colNames == rhs.colNames
        
    }
}



// MARK: - Conforms to the Printing Protocol

extension Matrix: CustomStringConvertible {
    public var description: String {
        var ret = String( "Matrix: (\(rows) x \(cols))")
        ret += "\n[\n"
        
        for r in 0 ..< rows {
            for c in 0 ..< cols {
                ret += String( " \(values[ (r*cols)+c])" )
            }
            ret += "\n"
        }
        ret += "]\n"
        return ret
    }
}







// MARK: - Algebraic Operations

extension Matrix {
    
    /// Centers each column to have mean zero.
    ///
    /// Subtracts the column mean from each element in that column. This is commonly
    /// used as a preprocessing step for PCA and other statistical analyses.
    ///
    /// - Note: This method modifies the matrix in place.
    ///
    /// ## Example
    /// ```swift
    /// let M = Matrix(3, 2, Vector([1.0, 4.0, 2.0, 5.0, 3.0, 6.0]))
    /// M.center()
    /// // Column means are now approximately 0.0
    /// ```
    public func center()  {
        let µ = self.colSum / Double( self.rows )
        for i in 0..<rows {
            for j in 0..<cols {
                self[i,j] = self[i,j] - µ[j]
            }
        }
    }
    
    
    /// Extracts a submatrix using specified row and column indices.
    ///
    /// - Parameters:
    ///   - r: Array of row indices to extract
    ///   - c: Array of column indices to extract
    /// - Returns: A new matrix containing only the specified rows and columns
    ///
    /// ## Example
    /// ```swift
    /// let M = Matrix(4, 4, 1.0...16.0)
    /// let sub = M.submatrix([0, 2], [1, 3])
    /// // Extracts rows 0 and 2, columns 1 and 3
    /// ```
    public func submatrix(_ r: [Int], _ c: [Int] ) -> Matrix {
        let ret = Matrix(r.count, c.count, 0.0 )
        for i in 0..<r.count {
            for j in 0..<c.count {
                ret[i,j] = self[ r[i], c[j] ]
            }
        }
        return ret
    }
    
    
    /// Rowwise Distance Matrix
    ///
    /// - Parameters:
    ///     - m: Matrix where each row is a "coordinate space" for each observation
    /// - Returns: An NxN matrix (symmetrical) of pairwise distances
    public var distanceMatrix: Matrix {
        
        let n = self.rows
        let ret = Matrix(n, n, 0.0)
        
        for i in 0..<n {
            let pointI = self.getRow(r: i)
            for j in i..<n {
                if i != j {
                    let pointJ = self.getRow(r: j)
                    let dist = euclideanDistance(pointI, pointJ)
                    ret[i,j] = dist
                    ret[j,i] = dist
                }
            }
        }
        return ret
    }
    
    
    
}




extension Matrix {
    
    /// Creates a design matrix from categorical data.
    ///
    /// Converts a vector of category labels into a binary design matrix where each column
    /// represents a category and each row has a 1 in the column corresponding to its category.
    ///
    /// - Parameter strata: Array of category labels
    /// - Returns: An N×K matrix where N is the number of observations and K is the number
    ///   of unique categories
    ///
    /// ## Example
    /// ```swift
    /// let groups = ["A", "A", "B", "B", "C"]
    /// let X = Matrix.DesignMatrix(strata: groups)
    /// // Results in a 5×3 matrix with 1s indicating group membership
    /// ```
    public static func DesignMatrix( strata: [String] ) -> Matrix {
        
        let r = strata.count
        let colNames = Array<String>( Set<String>(strata) ).sorted()
        let X = Matrix(r, colNames.count, 0.0 )
        
        for i in 0 ..< r {
            if let c = colNames.firstIndex(where: { $0 == strata[i] } ) {
                X[i,c] = 1.0
            }
        }
        return X
    }
    
    /// Creates an idempotent hat matrix for categorical data.
    ///
    /// Computes the hat matrix **H** = X(X'X)⁻¹X' where X is the design matrix for the given strata.
    /// The hat matrix projects data onto the space spanned by the group means.
    ///
    /// - Parameter strata: Array of category labels
    /// - Returns: An N×N idempotent projection matrix
    ///
    /// Used in variance partitioning and analysis of variance (AMOVA).
    public static func IdempotentHatMatrix( strata: [String] ) -> Matrix {
        
        let X = Matrix.DesignMatrix(strata: strata)
        let H = X .* GeneralizedInverse( X.transpose .* X ) .* X.transpose
        
        return H
        
    }
    
    /// Creates a diagonal matrix from a vector.
    ///
    /// - Parameter diagonal: Vector of values to place on the diagonal
    /// - Returns: An N×N matrix where N is the length of the diagonal vector,
    ///   with specified values on the diagonal and zeros elsewhere
    ///
    /// ## Example
    /// ```swift
    /// let D = Matrix.DiagonalMatrix(diagonal: [1.0, 2.0, 3.0])
    /// // Results in:
    /// // [1.0, 0.0, 0.0]
    /// // [0.0, 2.0, 0.0]
    /// // [0.0, 0.0, 3.0]
    /// ```
    public static func DiagonalMatrix( diagonal: Vector ) -> Matrix {
        let N = diagonal.count
        let X = Matrix(N,N,0.0)
        for i in 0 ..< N {
            X[i,i] = diagonal[i]
        }
        return X
    }
    
    
    
    
    
}





extension Matrix: rSourceConvertible {
    
    /// This converts the matrix to an R object.  If the matrix has column names then it will be made into a tibble else, it will be made into a matrix.
    public func toR() -> String {
        var ret = [String]()
        
        let hasColNames = !self.colNames.compactMap({$0.isEmpty}).allSatisfy({$0})
        
        if hasColNames { // Result will be tibble
            ret.append("tibble(")
            
            // If there are rownames, put them in as Key
            if !self.rowNames.compactMap( {$0.isEmpty}).allSatisfy({$0} ) {
                var vals = String( "  Key = c(")
                vals += rowNames.map{ String("'\($0)'")}.joined(separator: ", ")
                vals += "),"
                ret.append( vals )
            }
            
            for i in 0 ..< colNames.count {
                let name = colNames[i]
                var vals = String( "  \(name) = ")
                vals += self.getCol(c:i).toR()
                if i < (colNames.count-1) {
                    vals += ","
                }
                ret.append( vals )
            }
            
            
            ret.append( ")" )
            return ret.joined(separator: "\n")
        }
        else { // Result is Matrix
            var vals = "matrix( c("
            vals += self.values.compactMap{ String("\($0)")}.joined(separator: ",")
            vals += String( "), ncol=\(self.cols), nrow=\(self.rows), byrow=TRUE)")
            return vals
        }
    }
    
}

