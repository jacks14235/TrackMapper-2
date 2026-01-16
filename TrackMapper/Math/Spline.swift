//
//  Spline.swift
//  TrackMapper
//
//  Created by Jack Stanley on 3/5/25 with help from ChatGPT.
//
import Foundation
import Accelerate

struct Coordinate: Equatable, Hashable, Codable {
    var x: Double
    var y: Double
    
    static let zero = Coordinate(x: 0, y: 0)
    static let ones = Coordinate(x: 1, y: 1)
    
    var lon: Double {
        get { x }
        set { x = newValue }
    }
    
    var lat: Double {
        get { y }
        set { y = newValue }
    }
    
    static func == (lhs: Coordinate, rhs: Coordinate) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
    
    static func fromRealArray(array: [Double]) -> Coordinate {
        precondition(array.count == 2, "Must be a 2D coordinate")
        return Coordinate(x: array[0], y: array[1])
    }
    
}

struct CoordPair: Equatable, Hashable, Codable {
    var real: Coordinate
    var map: Coordinate
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(real)
    }
    
    static func removeDuplicates(_ pairs: [CoordPair]) -> ([Coordinate], [Coordinate]) {
        var seen = Set<CoordPair>()
        var orderedUnique: [CoordPair] = []
        for pair in pairs {
            if !seen.contains(pair) {
                seen.insert(pair)
                orderedUnique.append(pair)
            }
        }
        let uniqueReal = orderedUnique.map { $0.real }
        let uniqueMap = orderedUnique.map { $0.map }
        
        return (uniqueReal, uniqueMap)
    }
    
    static func fromRealArrays(reals: [Coordinate], maps: [Coordinate]) -> [CoordPair] {
        return self.fromRealArrays(reals: reals.map {[$0.x, $0.y]}, maps: maps.map {[$0.x, $0.y]})
    }
    
    static func fromRealArrays(reals: [[Double]], maps: [[Double]]) -> [CoordPair] {
        var pairs: [CoordPair] = []
        for i in 0..<reals.count {
            let real = Coordinate(x: reals[i][0], y: reals[i][1])
            let map = Coordinate(x: maps[i][0], y: maps[i][1])
            pairs.append(CoordPair(real: real, map: map))
        }
        return pairs
    }
    
    static func == (lhs: CoordPair, rhs: CoordPair) -> Bool {
        return lhs.real == rhs.real
    }
}

class Spline: Equatable {
    public var realCoords: [Coordinate]
    public var mapCoords: [Coordinate]
    private var realMatrix: Matrix
    var realScale: Coordinate
    var realTrans: Coordinate
    var mapScale: Coordinate
    var mapTrans: Coordinate
    var D: Matrix // 3 x 2
    var c: Matrix // 2 x m
    let m: Int
    
    init(coordinates: [CoordPair]) {
        let (realCoordsUnique, mapCoordsUnique) = CoordPair.removeDuplicates(coordinates)
        self.realCoords = realCoordsUnique
        self.mapCoords = mapCoordsUnique
        
        // can't make a spline with less than 3 points
        if coordinates.count < 3 {
            self.m = coordinates.count
            realTrans = .zero
            realScale = .ones
            mapTrans = .zero
            mapScale = .ones
            self.realMatrix = Matrix.zeros(rows: m, cols: 2)
            self.D = Matrix.zeros(rows: 3, cols: 2)
            self.c = Matrix.zeros(rows: 2, cols: m)
            return
        }
        
        // rescale coordinates to be between 0 and 1
        let realXs = realCoordsUnique.map({$0.x})
        let realYs = realCoordsUnique.map({$0.y})
        self.realTrans = Coordinate(x: -realXs.min()!, y: -realYs.min()!)
        self.realScale = Coordinate(x: 1.0/(realXs.max()! - realXs.min()!), y: 1.0/(realYs.max()! - realYs.min()!))
        let mapXs = mapCoordsUnique.map({$0.x})
        let mapYs = mapCoordsUnique.map({$0.y})
        self.mapTrans = Coordinate(x: -mapXs.min()!, y: -mapYs.min()!)
        self.mapScale = Coordinate(x: 1.0/(mapXs.max()! - mapXs.min()!), y: 1.0/(mapYs.max()! - mapYs.min()!))
        
        
        let m = realCoordsUnique.count
        self.m = m
        let realMatrix = Spline.scaled(coords: realCoordsUnique, trans: realTrans, scale: realScale)
        self.realMatrix = realMatrix
        
        let A = Matrix(rows: m, cols: 3, values: realMatrix.data + [Float](repeating: 1.0, count: m))
//        var B = Matrix(rows: m, cols: 2, rowMajorValues: mapCoordsUnique.flatMap { [$0.x, $0.y] })
        let B = Spline.scaled(coords: mapCoordsUnique, trans: mapTrans, scale: mapScale)
                
        let AT = A.transposed()
        let ATA = (AT • A) // TODO: handle error for singular matrix (or not)
        let D = ATA.inverse()! • AT • B
        self.D = D
        
        let distanceMatrix = Spline.getDistanceMatrix(A: A, m: m, B: A, n: m, k: 3)
        
        var phi = distanceMatrix * distanceMatrix * Matrix.log(distanceMatrix)
        
        // replace diagonals with 0 instead of -inf
        // don't need to worry about other points because we checked for unique points
        var val: Float = 1e-6
        vDSP_vfill(&val, &phi.data, m + 1, vDSP_Length(m))
        
        let affine = A • D
        let error = affine - B
        self.c = (phi.inverse()! • error).transposed()
    }
    
    /// inits a new spline with all the reference points of this one plus a new one
    func withAddedPoint(newRealCoord: Coordinate, newMapCoord: Coordinate) -> Spline {
        var pairs = self.realCoords.enumerated().map { (i, real) in CoordPair(real: real, map: self.mapCoords[i]) }
        pairs.append(CoordPair(real: newRealCoord, map: newMapCoord))
        return Spline(coordinates: pairs)
    }
    
    static func == (lhs: Spline, rhs: Spline) -> Bool {
        return lhs === rhs // Compare references, not values
    }
    
    static func getDistanceMatrix(A: Matrix, m: Int, B: Matrix, n: Int, k: Int) -> Matrix {
        return Spline.getDistanceMatrix(A: A, m: m, B: B, n: n, k: k, aNorms: A.sumOfSquares(), bNorms: B.sumOfSquares())
    }
    
    /// A is a set of n 3D points, norms is the magnitude of each point in A and B
    /// A is mxk, B is nxk
    /// Returns an nxm matrix where entry i,j is the distance between Ai and Aj
    static func getDistanceMatrix(A: Matrix, m: Int, B: Matrix, n: Int, k: Int, aNorms: [Float], bNorms: [Float]) -> Matrix {
        precondition(A.rows == m)
        precondition(A.cols == k)
        precondition(B.rows == n)
        precondition(B.cols == k)
        
        // get outer sum of norms of matrices
        let aNorms = Matrix(rows: m, cols: 1, values: aNorms)
        let bNorms = Matrix(rows: n, cols: 1, values: bNorms)
        
        let aExpand = aNorms.expandCols(n) // mxn
        let bExpand = bNorms.transposed().expandRows(m) // mxn
        let outerSum = aExpand + bExpand
        
        // calculate gram matrix -2AB^T
        var gramMatrixData = [Float](repeating: 0, count: m * n)
        gramMatrixData.withUnsafeMutableBufferPointer { data in
            cblas_sgemm(
                CblasColMajor, CblasNoTrans, CblasTrans,
                m, n, k,
                -2.0, A.data, m, B.data, n,
                0.0, data.baseAddress!, m
            )
        }
        let gramMatrix = Matrix(rows: m, cols: n, values: gramMatrixData)
        
        // distance between points i and j is ||A||^2 + ||B^||^2 - 2AB^T
        let distanceMatrix = outerSum + gramMatrix
        
        return Matrix.sqrt(distanceMatrix)
    }
    
    func scaledReal(_ coords: [Coordinate]) -> Matrix {
        return Spline.scaled(coords: coords, trans: self.realTrans, scale: self.realScale)
    }
    
    /// Takes in Coordinates (double precision), scales between 0 and 1, then converts to float
    private static func scaled(coords: [Coordinate], trans: Coordinate, scale: Coordinate) -> Matrix {
        let doubles = coordinatesToDoubles(coords)
        let n = coords.count
        
        let scaledData = [Double](unsafeUninitializedCapacity: n * 2) {
            buffer, initializedCount in
            // x scale
            var xtrans = trans.x
            var xscale = scale.x
            withUnsafeMutablePointer(to: &xscale) { scale in
                withUnsafeMutablePointer(to: &xtrans) { trans in
                    vDSP_vsaddD(doubles, 2, trans, buffer.baseAddress!, 2, vDSP_Length(n))
                    vDSP_vsmulD(buffer.baseAddress!, 2, scale, buffer.baseAddress!, 2, vDSP_Length(n))
                }
            }
            
            // y scale
            var ytrans = trans.y
            var yscale = scale.y
            withUnsafeMutablePointer(to: &yscale) { scale in
                withUnsafeMutablePointer(to: &ytrans) { trans in
                    doubles.withUnsafeBufferPointer { dataPtr in
                        vDSP_vsaddD(dataPtr.baseAddress! + 1, 2, trans, buffer.baseAddress! + 1, 2, vDSP_Length(n))
                    }
                    vDSP_vsmulD(buffer.baseAddress! + 1, 2, scale, buffer.baseAddress! + 1, 2, vDSP_Length(n))
                }
            }
            
            initializedCount = n * 2
        }
        var floats = [Float](repeating: 0, count: n * 2)
        vDSP_vdpsp(scaledData, 1, &floats, 1, vDSP_Length(n * 2))
        return Matrix(rows: 2, cols: n, values: floats).transposed()
    }
    
    private static func unscaled(_ m: Matrix, trans: Coordinate, scale: Coordinate) -> [Coordinate] {
        precondition(m.cols == 2, "Can only scale 2D coordinates")
        var doubles = [Double](repeating: 0, count: m.rows * m.cols)
        vDSP_vspdp(m.data, 1, &doubles, 1, vDSP_Length(m.rows * m.cols))
        
        let scaledData = [Double](unsafeUninitializedCapacity: m.rows * 2) {
            buffer, initializedCount in
            // x scale
            var xtrans = -trans.x
            var xscale = 1.0 / scale.x
            withUnsafeMutablePointer(to: &xscale) { scale in
                withUnsafeMutablePointer(to: &xtrans) { trans in
                    vDSP_vsmulD(doubles, 1, scale, buffer.baseAddress!, 1, vDSP_Length(m.rows))
                    vDSP_vsaddD(buffer.baseAddress!, 1, trans, buffer.baseAddress!, 1, vDSP_Length(m.rows))
                }
            }
            
            // y scale
            var ytrans = -trans.y
            var yscale = 1.0 / scale.y
            withUnsafeMutablePointer(to: &yscale) { scale in
                withUnsafeMutablePointer(to: &ytrans) { trans in
                    doubles.withUnsafeBufferPointer { dataPtr in
                        vDSP_vsmulD(dataPtr.baseAddress! + m.rows, 1, scale, buffer.baseAddress! + m.rows, 1, vDSP_Length(m.rows))
                    }
                    vDSP_vsaddD(buffer.baseAddress! + m.rows, 1, trans, buffer.baseAddress! + m.rows, 1, vDSP_Length(m.rows))
                }
            }
            
            initializedCount = m.rows * 2
        }
        let transposed = [Double](unsafeUninitializedCapacity: m.rows * m.cols) { buffer, initializedCount in
            vDSP_mtransD(scaledData, 1, buffer.baseAddress!, 1, vDSP_Length(m.rows), vDSP_Length(m.cols))
            initializedCount = m.rows * m.cols
        }
        
        return doublesToCoordinates(transposed)
    }
    
    public func warp(_ points: [Coordinate]) -> [Coordinate] {
        if points.count == 0 { return [] }
        let A = self.realMatrix
        let n = points.count
        if self.m < 3 {
            return [Coordinate](repeating: Coordinate(x: 0, y: 0), count: n)
        }
        let B = Spline.scaled(coords: points, trans: self.realTrans, scale: self.realScale)
        let B3 = Matrix(rows: n, cols: 3, values: B.data + [Float](repeating: 1.0, count: n))
        let distanceMatrix = Spline.getDistanceMatrix(A: A, m: self.m, B: B, n: n, k: 2)
        let phi = distanceMatrix * distanceMatrix * Matrix.log(distanceMatrix)
        
        let left = B3 • self.D
        let right = (self.c • phi).transposed()
        let result = left - right
        let unscaled = Spline.unscaled(result, trans: self.mapTrans, scale: mapScale)
        return unscaled
    }

    
}

struct PairsData: Codable {
    let N: Int
    let pairs: [CoordPair]
}

extension Spline {
    static func fromJSON(jsonFile: String) -> Spline? {
        let parts = jsonFile.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard let url = Bundle.main.url(forResource: String(parts[0]), withExtension: String(parts[1])) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let decodedData = try JSONDecoder().decode(PairsData.self, from: data)
            
            return Spline(coordinates: decodedData.pairs)
        } catch {
            print("Error loading JSON:", error)
            return nil
        }
    }
    
    func getCenter() -> Coordinate {
        let total = self.realCoords.reduce(Coordinate(x: 0, y: 0)) { sum, coord in
            Coordinate(x: sum.x + coord.x, y: sum.y + coord.y)
        }
        return Coordinate(x: total.x / Double(self.m), y: total.y / Double(self.m))
    }
    
    func getPairs() -> [CoordPair] {
        return self.realCoords.enumerated().map { (i, coord) in
            CoordPair(real: coord, map: self.mapCoords[i])
        }
    }
    
    func toJSON() -> String {
        let pairs = self.getPairs()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try encoder.encode(pairs)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            print("Error encoding JSON: \(error)")
            return "{}"
        }
    }

}

func loadCoordinates(from jsonFile: String) -> ([[Double]], [[Double]])? {
    guard let url = URL(string: jsonFile) else { return nil }

    do {
        let data = try Data(contentsOf: url)
        let decodedData = try JSONDecoder().decode(PairsData.self, from: data)
        
        print("\(decodedData.pairs.count) starting points")
        let realCoords = decodedData.pairs.map { [$0.real.x, $0.real.y] }
        let mapCoords = decodedData.pairs.map { [$0.map.x, $0.map.y] }
        
        return (realCoords, mapCoords)
    } catch {
        print("Error loading JSON:", error)
        return nil
    }
}

func coordinatesToDoubles(_ coordinates: [Coordinate]) -> [Double] {
    return coordinates.withUnsafeBytes { rawBuffer in
        let doubleBuffer = rawBuffer.bindMemory(to: Double.self)
        return Array(doubleBuffer)
    }
}

func doublesToCoordinates(_ doubles: [Double]) -> [Coordinate] {
    precondition(doubles.count % 2 == 0, "Must be an even number of doubles")
    return doubles.withUnsafeBytes { rawBuffer in
        let coordBuffer = rawBuffer.bindMemory(to: Coordinate.self)
        return Array(coordBuffer)
    }
}

