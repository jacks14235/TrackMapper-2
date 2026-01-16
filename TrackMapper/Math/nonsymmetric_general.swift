/*
From https://developer.apple.com/documentation/accelerate/solving-systems-of-linear-equations-with-lapack
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Solver function for nonsymmetric general matrices.
*/


import Accelerate
typealias __LAPACK_int = Int
typealias __CLPK_integer = Int
/// Returns the _x_ in _Ax = b_ for a nonsquare coefficient matrix using `sgesv_`.
///
/// - Parameter a: The matrix _A_ in _Ax = b_ that contains `dimension * dimension`
/// elements.
/// - Parameter dimension: The order of matrix _A_.
/// - Parameter b: The matrix _b_ in _Ax = b_ that contains `dimension * rightHandSideCount`
/// elements.
/// - Parameter rightHandSideCount: The number of columns in _b_.
///
/// The function specifies the leading dimension (the increment between successive columns of a matrix)
/// of matrices as their number of rows.

/// - Tag: nonsymmetric_general
func nonsymmetric_general(a: [Float],
                          dimension: Int,
                          b: [Float],
                          rightHandSideCount: Int) -> [Float]? {
    
    var info: __LAPACK_int = 0
    
    /// Create a mutable copy of the right hand side matrix _b_ that the function returns as the solution matrix _x_.
    var x = b
    
    /// Create a mutable copy of `a` to pass to the LAPACK routine. The routine overwrites `mutableA`
    /// with the factors `L` and `U` from the factorization `A = P * L * U`.
    var mutableA = a
    
    var ipiv = [__LAPACK_int](repeating: 0, count: dimension)
    
    var mutableZ = a
    var pivots = [__CLPK_integer](repeating: 0, count: dimension)
    var info1: __CLPK_integer = 0
    var n144 = __CLPK_integer(dimension)
    var n234 = __CLPK_integer(n144)
    var n334 = __CLPK_integer(n144)

    sgetrf_(&n234, &n144, &mutableZ, &n334, &pivots, &info1)

    if info1 > 0 {
        print("Matrix is singular at column \(info1)")
    } else if info < 0 {
        print("Argument \(-info1) has an illegal value")
    }
    
    /// Call `sgesv_` to compute the solution.
    var n = __CLPK_integer(dimension)
    var nrhs = __CLPK_integer(rightHandSideCount)
    withUnsafeMutablePointer(to: &n) { n1 in
        withUnsafeMutablePointer(to: &nrhs) { nrhs1 in
            sgesv_(n1,
                   nrhs1,
                   &mutableA,
                   n1,
                   &ipiv,
                   &x,
                   n1,
                   &info)
        }
    }
    
    if info != 0 {
        NSLog("nonsymmetric_general error \(info)")
        return nil
    }
    return x
}
