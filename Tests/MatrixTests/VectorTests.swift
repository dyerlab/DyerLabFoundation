//
//  MatrixTests.swift
//  Tests macOS
//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Created by Rodney Dyer on 6/7/21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
import SceneKit
import CoreGraphics

@testable import Matrix

struct VectorTests {
    
    @Test
    func testInit() {
        let v = Vector(repeating: 2.2, count: 4 )
        
        #expect(v.count == 4)
        #expect(v.sum == 8.8)

        #expect(v[1] == 2.2)
        #expect(v.magnitude == sqrt( 19.36))
        #expect(v.normal == [0.5, 0.5, 0.5, 0.5])
        
        let v1 = Vector([1.0,2.0,3.0])
        #expect(v1.x == 1.0)
        #expect(v1.y == 2.0)

        #expect(v1.asCGPoint == CGPoint( x: 1.0, y: 2.0) )
        
        let v1svn = v1.asSNCVector3
        #expect(v1svn.x == 1.0)
        #expect(v1svn.y == 2.0)
        #expect(v1svn.z == 3.0)
        
        let v2 = [-2.3, 2.1, 2.8]
        #expect(v2.limitAnnealingMagnitude(temp: 2.2) == [-2.2, 2.1, 2.2 ])
        #expect(Vector.zeros(3) == [0.0, 0.0, 0.0])

    }

    @Test
    func testEqualityRequiresAllElements() {
        // Regression: `==` must require *every* element to match, not just one.
        let a = Vector([1.0, 2.0, 3.0])
        #expect(!(a == [1.0, 99.0, 99.0]))   // first element matches; still unequal
        #expect(!(a == [99.0, 2.0, 3.0]))    // last two match; still unequal
        #expect(a == [1.0, 2.0, 3.0])        // identical → equal
        #expect(!(a == [1.0, 2.0]))          // different length → unequal
        #expect(Vector() == Vector())        // both empty → equal
    }
    
    
    @Test
    func testOperators() {
        
        let x = [ 1.0 ,2.0, 3.0 ]
        let y = [ 3.0, 2.0, 1.0 ]
        let s = 2.0
        
        #expect(x+s == [3.0, 4.0, 5.0])
        #expect(x-s == [-1.0, 0.0, 1.0])
        #expect(x*s == [2.0, 4.0, 6.0])
        // Division goes through vDSP, which may differ from Swift's `/` in the last
        // ULP, so compare with a tolerance rather than exact equality.
        #expect(isApprox(x/s, [1.0/2.0, 2.0/2.0, 3.0/2.0]))

        #expect(x + y == [4.0, 4.0, 4.0])
        #expect(x - y == [-2.0, 0.0, 2.0])
        #expect(x * y == [3.0, 4.0, 3.0])
        #expect(isApprox(x / y, [1.0/3.0, 2.0/2.0, 3.0/1.0]))

        #expect(x .* y == 10.0)
        #expect(isApprox(euclideanDistance(x, y), sqrt((x - y).map { $0 * $0 }.sum)))
        
        #expect(amovaDistance( [ 0.0, 2.0, 0.0], [ 2.0, 0.0, 0.0] ) == 4.0)
        #expect(amovaDistance( [ 0.0, 2.0, 0.0], [ 1.0, 1.0, 0.0] ) == 1.0)
        #expect(amovaDistance( [ 1.0, 0.0, 1.0], [ 0.0, 2.0, 0.0] ) == 3.0)
        #expect(amovaDistance( [ 1.0, 1.0, 0.0], [ 0.0, 1.0, 1.0] ) == 1.0)
        #expect(amovaDistance( [ 2.0, 0.0, 0.0], [ 2.0, 0.0, 0.0] ) == 0.0)
        #expect(amovaDistance( [ 1.0, 1.0, 0.0, 0.0], [ 0.0, 0.0, 1.0, 1.0] ) == 2.0)

    }
    
    
    
    @Test
    func testRSourceConvertable() {
        
        let x = Vector(repeating: 1.0, count: 10)
        #expect(x.count == 10)
        
        let r = x.toR()
        #expect(!r.isEmpty)
        #expect(r == "c(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0)")
        
    }
    
    
    @Test
    func testStudentize() throws {
        // `#require` fails the test if studentization unexpectedly returns nil,
        // rather than silently skipping the assertions.
        let x = try #require(Vector([1, 2, 3, 4, 5]).studentized)
        #expect(x.sum == 2.5)

        let z = try #require(Vector([-34, -23, -12, 10, 110]).studentized)
        #expect(z.minimum == 0.0)
        #expect(z.maximum == 1.0)
    }

    @Test
    func testStudentizeReturnsNil() {
        // No minimum (empty) or a zero range (constant) cannot be studentized.
        #expect(Vector().studentized == nil, "Empty vector cannot be studentized")
        #expect(Vector([5.0, 5.0, 5.0]).studentized == nil, "Constant vector has zero range")
    }

    @Test
    func testSquaredEuclideanDistance() {
        #expect(squaredEuclideanDistance([0.0, 0.0], [3.0, 4.0]) == 25.0)
        #expect(squaredEuclideanDistance([1.0, 2.0, 3.0], [1.0, 2.0, 3.0]) == 0.0)
    }

    @Test
    func testRandomNormalizedVector() {
        let v = Vector.randomNormalizedVector(size: 16)
        #expect(v.count == 16)
        #expect(isApprox(v.magnitude, 1.0), "Should be a unit vector")
    }

    @Test
    func testVectorStatistics() {
        let v = Vector([1.0, 2.0, 3.0, 4.0, 5.0])

        // Test mean
        #expect(v.mean == 3.0, "Mean should be 3.0")

        // Test variance
        // Variance = sum((x - mean)^2) / (n-1)
        // = ((1-3)^2 + (2-3)^2 + (3-3)^2 + (4-3)^2 + (5-3)^2) / 4
        // = (4 + 1 + 0 + 1 + 4) / 4 = 10/4 = 2.5
        #expect(v.variance == 2.5, "Variance should be 2.5")

        // Test standard deviation
        let expectedSD = sqrt(2.5)
        #expect(abs(v.sd - expectedSD) < 0.0001, "SD should be sqrt(2.5)")
    }

    @Test
    func testVectorMinMax() {
        let v = Vector([3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0])

        #expect(v.minimum == 1.0, "Minimum should be 1.0")
        #expect(v.maximum == 9.0, "Maximum should be 9.0")
    }

    @Test
    func testVectorSmallestLargest() {
        let v1 = Vector([1.0, 5.0, 3.0])
        let v2 = Vector([2.0, 3.0, 4.0])

        let smallest = v1.smallest(other: v2)
        #expect(smallest == [1.0, 3.0, 3.0], "Smallest should be element-wise minimum")

        let largest = v1.largest(other: v2)
        #expect(largest == [2.0, 5.0, 4.0], "Largest should be element-wise maximum")
    }

    @Test
    func testVectorConstrain() {
        let v = Vector([1.0, 5.0, 10.0, 15.0, 20.0])
        let constrained = v.constrain(minimum: 5.0, maximum: 15.0)

        #expect(constrained == [5.0, 5.0, 10.0, 15.0, 15.0], "Values should be constrained to [5, 15]")
    }

    @Test
    func testVectorZeros() {
        let v = Vector.zeros(5)

        #expect(v.count == 5, "Should have 5 elements")
        #expect(v.sum == 0.0, "All elements should be zero")
    }

    @Test
    func testVectorRandom() throws {
        // Test uniform [0,1]
        let v1 = Vector.random(length: 100, type: .uniform_0_1)
        #expect(v1.count == 100, "Should have 100 elements")

        let min1 = try #require(v1.minimum)
        let max1 = try #require(v1.maximum)
        #expect(min1 >= 0.0, "Minimum should be >= 0")
        #expect(max1 <= 1.0, "Maximum should be <= 1")

        // Test uniform [-1,1]
        let v2 = Vector.random(length: 100, type: .uniform_neg1_1)
        #expect(v2.count == 100, "Should have 100 elements")

        let min2 = try #require(v2.minimum)
        let max2 = try #require(v2.maximum)
        #expect(min2 >= -1.0, "Minimum should be >= -1")
        #expect(max2 <= 1.0, "Maximum should be <= 1")

        // Test normal distribution: should be finite and actually vary
        // (a broken generator returning all-zeros or NaN would be caught here).
        let v3 = Vector.random(length: 100, type: .normal_0_1)
        #expect(v3.count == 100, "Should have 100 elements")
        #expect(v3.allSatisfy { $0.isFinite }, "All normal samples should be finite")
        #expect(v3.variance > 0, "Normal samples should have non-zero spread")
    }

    @Test
    func testVectorEmptyStatistics() {
        let v = Vector()

        #expect(v.mean.isNaN, "Mean of empty vector should be NaN")
        #expect(v.variance.isNaN, "Variance of empty vector should be NaN")
        #expect(v.sd.isNaN, "SD of empty vector should be NaN")
    }

    @Test
    func testVectorZ() {
        let v = Vector([1.0, 2.0, 3.0])
        #expect(v.z == 3.0, "z should return third element")

        let v2 = Vector([1.0, 2.0])
        #expect(v2.z == 0.0, "z should return 0.0 when vector has < 3 elements")
    }

}
