//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  ClusteringTests.swift
//
//
//  Created by Rodney Dyer on 2026-02-24.
//

import Foundation
import Testing
@testable import PresentationZen

@Suite("Point3D")
struct Point3DTests {

    @Test("zero constant is (0,0,0)")
    func zeroConstant() {
        #expect(Point3D.zero == Point3D(0, 0, 0))
    }

    @Test("equality compares all three components")
    func equality() {
        #expect(Point3D(1, 2, 3) == Point3D(1, 2, 3))
        #expect(Point3D(1, 2, 3) != Point3D(1, 2, 4))
    }

    @Test("squaredDistance computes correct value")
    func squaredDistance() {
        // (3,4,0) from origin → 9+16+0 = 25
        #expect(Point3D.zero.squaredDistance(to: Point3D(3, 4, 0)) == 25.0)
        #expect(Point3D(1, 1, 1).squaredDistance(to: Point3D(1, 1, 1)) == 0.0)
    }

    @Test("addition operator sums components")
    func addition() {
        #expect(Point3D(1, 2, 3) + Point3D(4, 5, 6) == Point3D(5, 7, 9))
    }

    @Test("division by scalar divides each component")
    func division() {
        #expect(Point3D(4, 6, 8) / 2 == Point3D(2, 3, 4))
    }
}

@Suite("PointCluster")
struct PointClusterTests {

    @Test("estimateCenter returns zero for empty cluster")
    func emptyCenterEstimate() {
        let cluster = PointCluster(center: Point3D.zero)
        #expect(cluster.estimateCenter() == Point3D.zero)
    }

    @Test("estimateCenter computes centroid of points")
    func centroid() {
        let cluster = PointCluster(center: Point3D.zero)
        cluster.points = [Point3D(0, 0, 0), Point3D(6, 0, 0), Point3D(3, 0, 0)]
        let center = cluster.estimateCenter()
        #expect(abs(center.x - 3.0) < 0.001)
        #expect(center.y == 0)
        #expect(center.z == 0)
    }

    @Test("updateCenter picks the actual point nearest to centroid")
    func updateCenter() {
        let cluster = PointCluster(center: Point3D.zero)
        // centroid = (5/3, 0, 0) ≈ 1.667; nearest actual point is (2, 0, 0)
        cluster.points = [Point3D(0, 0, 0), Point3D(3, 0, 0), Point3D(2, 0, 0)]
        cluster.updateCenter()
        #expect(cluster.center == Point3D(2, 0, 0))
    }

    @Test("updateCenter does nothing for empty cluster")
    func updateCenterEmpty() {
        let original = Point3D(1, 2, 3)
        let cluster = PointCluster(center: original)
        cluster.updateCenter()
        #expect(cluster.center == original)
    }
}

@Suite("kMeansClustering")
struct KMeansClusteringTests {

    @Test("returns exactly k clusters")
    func clusterCount() {
        let points = (0..<12).map { i in Point3D(CGFloat(i), 0, 0) }
        let clusters = kMeansClustering(points: points, k: 3)
        #expect(clusters.count == 3)
    }

    @Test("all input points are assigned to exactly one cluster")
    func completeAssignment() {
        let points = (0..<9).map { i in Point3D(CGFloat(i), 0, 0) }
        let clusters = kMeansClustering(points: points, k: 3)
        let totalAssigned = clusters.reduce(0) { $0 + $1.points.count }
        #expect(totalAssigned == points.count)
    }

    @Test("clusters are sorted descending by point count")
    func sortedBySize() {
        let points = (0..<10).map { i in Point3D(CGFloat(i), 0, 0) }
        let clusters = kMeansClustering(points: points, k: 3)
        for i in 0 ..< clusters.count - 1 {
            #expect(clusters[i].points.count >= clusters[i + 1].points.count)
        }
    }

    @Test("k=1 assigns all points to a single cluster")
    func singleCluster() {
        let points = (0..<8).map { i in Point3D(CGFloat(i), 0, 0) }
        let clusters = kMeansClustering(points: points, k: 1)
        #expect(clusters.count == 1)
        #expect(clusters[0].points.count == 8)
    }
}
