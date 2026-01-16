//
//  Matrix.swift
//  TrackMapper
//
//  Created by Jack Stanley on 3/5/25 with help from ChatGPT.
//

import Accelerate

infix operator •: MultiplicationPrecedence
prefix operator !

struct Matrix {
    var rows: Int
    var cols: Int
    var data: [Float]
    
    var shape: [Int] {
        get {[rows, cols]}
    }

    /// Initialize with a flat 1D array (column-major order)
    init(rows: Int, cols: Int, values: [Float]) {
        precondition(values.count == rows * cols, "Value count must match matrix size")
        self.rows = rows
        self.cols = cols
        self.data = values
    }
    
    /// Initializes a matrix from row-major order values and converts it to column-major order.
    init(rows: Int, cols: Int, rowMajorValues: [Float]) {
        precondition(rowMajorValues.count == rows * cols, "Value count must match matrix size")
        self.rows = cols
        self.cols = rows
        self.data = rowMajorValues
        let trans = self.transposed()
        
        self.rows = rows
        self.cols = cols
        self.data = trans.data
    }


    /// Initialize with a 2D array (row-major order, internally stored as column-major)
    init(_ array: [[Float]]) {
        let rowCount = array.count
        let colCount = array.first?.count ?? 0
        precondition(array.allSatisfy { $0.count == colCount }, "All rows must have the same number of columns")
        
        self.rows = rowCount
        self.cols = colCount
        self.data = Array(repeating: 0, count: rowCount * colCount)

        // Convert row-major to column-major
        for r in 0..<rowCount {
            for c in 0..<colCount {
                self.data[c * rowCount + r] = array[r][c]
            }
        }
    }
    
    init(identity size: Int) {
        self.rows = size
        self.cols = size
        self.data = Array(repeating: 0, count: size * size)

        for i in 0..<size {
            self.data[i * size + i] = 1 // Diagonal elements are 1
        }
    }
    
    static func zeros(rows: Int, cols: Int) -> Matrix {
        return Matrix(rows: rows, cols: cols, values: Array(repeating: 0, count: rows * cols))
    }

    /// Access matrix elements using 2D indexing (row-major order)
    subscript(row: Int, col: Int) -> Float {
        get {
            precondition(row >= 0 && row < rows && col >= 0 && col < cols, "Index out of bounds: [\(row)][\(col)]")
            return data[col * rows + row] // Column-major indexing
        }
        set {
            precondition(row >= 0 && row < rows && col >= 0 && col < cols, "Index out of bounds")
            data[col * rows + row] = newValue
        }
    }
    
    /// Element-wise matrix addition using Accelerate
    static func + (lhs: Matrix, rhs: Matrix) -> Matrix {
        precondition(lhs.rows == rhs.rows && lhs.cols == rhs.cols, "Matrix dimensions must match for addition")
        
        var result = [Float](repeating: 0, count: lhs.data.count)
        vDSP_vadd(lhs.data, 1, rhs.data, 1, &result, 1, vDSP_Length(lhs.data.count))
        
        return Matrix(rows: lhs.rows, cols: lhs.cols, values: result)
    }
    
    /// Element-wise matrix subtraction using Accelerate
    static func - (lhs: Matrix, rhs: Matrix) -> Matrix {
        precondition(lhs.rows == rhs.rows && lhs.cols == rhs.cols, "Matrix dimensions must match for subtraction")
        
        var result = [Float](repeating: 0, count: lhs.data.count)
        vDSP_vsub(rhs.data, 1, lhs.data, 1, &result, 1, vDSP_Length(lhs.data.count))
        
        return Matrix(rows: lhs.rows, cols: lhs.cols, values: result)
    }
    
    /// Element-wise matrix multiplication using Accelerate
    static func * (lhs: Matrix, rhs: Matrix) -> Matrix {
        precondition(lhs.rows == rhs.rows && lhs.cols == rhs.cols, "Matrix dimensions must match for element-wise multiplication")
        
        var result = [Float](repeating: 0, count: lhs.data.count)
        vDSP_vmul(rhs.data, 1, lhs.data, 1, &result, 1, vDSP_Length(lhs.data.count))
        
        return Matrix(rows: lhs.rows, cols: lhs.cols, values: result)
    }
    
    static func • (lhs: Matrix, rhs: Matrix) -> Matrix {
        precondition(lhs.cols == rhs.rows, "Matrix dimensions must align for multiplication")
        
        let m = lhs.rows
        let n = rhs.cols
        let k = lhs.cols
        
        var result = [Float](repeating: 0, count: m * n)
        
        let lda = max(1, lhs.rows)  // Leading dimension for lhs
        let ldb = max(1, rhs.rows)  // Leading dimension for rhs
        let ldc = max(1, m)         // Leading dimension for result
        
        cblas_sgemm(
            CblasColMajor,  // Column-major order (Accelerate uses Fortran-like storage)
            CblasNoTrans,    // lhs is not transposed
            CblasNoTrans,    // rhs is not transposed
            m,        // Rows of lhs (and result)
            n,        // Columns of rhs (and result)
            k,        // Shared dimension (lhs.cols == rhs.rows)
            1.0,             // Alpha (scaling factor for A*B)
            lhs.data,        // Pointer to lhs data
            lda,      // Leading dimension of lhs (fix for non-square matrices)
            rhs.data,        // Pointer to rhs data
            ldb,      // Leading dimension of rhs
            0.0,             // Beta (scaling factor for result)
            &result,         // Pointer to result storage
            ldc       // Leading dimension of result
        )
        
        return Matrix(rows: m, cols: n, values: result)
    }
    
    func inverse() -> Matrix? {
        precondition(self.rows == self.cols, "Matrix must be square to take inverse")
        let id = Matrix(identity: self.rows)
        let return_mat = nonsymmetric_general(a: self.data, dimension: self.rows, b: id.data, rightHandSideCount: self.rows)
        if let flat = return_mat {
            return Matrix(rows: self.rows, cols: self.cols, values: flat)
        } else {
            return nil
        }
    }
    
    static func log(_ m: Matrix) -> Matrix {
        var mc = m.copy()
        mc.data.withUnsafeMutableBufferPointer { buffer in
            vvlogf(buffer.baseAddress!, buffer.baseAddress!, [Int32(m.data.count)])
        }
        return mc
    }
    
    static func sqrt(_ m: Matrix) -> Matrix {
        var mc = m.copy()
        mc.data.withUnsafeMutableBufferPointer { buffer in
            vvsqrtf(buffer.baseAddress!, buffer.baseAddress!, [Int32(m.data.count)])
        }
        return mc
    }

    /// Returns the underlying 1D array (column-major order)
    func flatArray() -> [Float] {
        return data
    }

    /// Returns the matrix as a 2D array (row-major order)
    func to2DArray() -> [[Float]] {
        var array = [[Float]](repeating: [Float](repeating: 0, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                array[r][c] = self[r, c]
            }
        }
        return array
    }
    
    func expandRows(_ n: Int) -> Matrix {
        precondition(self.rows == 1, "Can only expand cols with a single row")
        let m = self.cols
        let expanded = [Float](unsafeUninitializedCapacity: n * m) {
            buffer, initializedCount in
            self.data.withUnsafeBufferPointer { data in
                for i in 0..<n {
                    let addr = buffer.baseAddress! + i
                    cblas_scopy(m, data.baseAddress!, 1, addr, n)
                }
            }
            initializedCount = m * n
        }
        return Matrix(rows: n, cols: self.cols, values: expanded)
    }
    
    func expandCols(_ m: Int) -> Matrix {
        precondition(self.cols == 1, "Can only expand cols with a single row")
        let n = self.rows
        let expanded = [Float](unsafeUninitializedCapacity: m * n) {
            buffer, initializedCount in
            self.data.withUnsafeBufferPointer { data in
                for i in 0..<m {
                    let addr = buffer.baseAddress! + i * self.rows
                    cblas_scopy(n, data.baseAddress!, 1, addr, 1)
                }
            }
            initializedCount = m * n
        }
        return Matrix(rows: self.rows, cols: m, values: expanded)
    }
    
    func copy() -> Matrix {
        return Matrix(rows: self.rows, cols: self.cols, values: self.data)
    }
    
    /// Returns the transpose of the matrix.
    func transposed() -> Matrix {
        let output = [Float](unsafeUninitializedCapacity: rows * cols) { buffer, initializedCount in
            vDSP_mtrans(self.data, 1, buffer.baseAddress!, 1, vDSP_Length(rows), vDSP_Length(cols))
            initializedCount = rows * cols
        }
        return Matrix(rows: self.cols, cols: self.rows, values: output)
    }
    
    func sumOfSquares() -> [Float] {
        var outData: [Float] = Array.init(repeating: 0, count: self.rows)
        for i in 0..<self.rows {
            self.data.withUnsafeBufferPointer { ptr in
                let ptr_offset = ptr.baseAddress! + i
                vDSP_svesq(ptr_offset, vDSP_Stride(self.rows), &outData[i], vDSP_Length(self.cols))
            }
        }
        
        return outData
    }
    
}


extension Matrix: CustomStringConvertible {
    var description: String {
        var result = ""
        for r in 0..<rows {
            let rowValues = (0..<cols).map { String(format: "%7.3f", self[r, $0]) }
            result += "[ " + rowValues.joined(separator: " ") + " ]\n"
        }
        return result
    }
}


