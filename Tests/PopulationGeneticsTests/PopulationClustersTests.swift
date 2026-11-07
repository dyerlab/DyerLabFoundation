//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopulationClustersTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.10.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import MapKit
import Testing
import PresentationZen
@testable import PopulationGenetics

struct PopulationClustersTests {

    private func exampleClusters() throws -> PopulationClusters {
        PopulationClusters(dataset: try TestData.dataset(TestData.exampleCSV()))
    }

    @Test func groupsIndividualsByPopulationAroundTheirCentroid() throws {
        let clusters = try exampleClusters()
        #expect(clusters.clusters.count == 25)
        #expect(clusters.unlocatedOrdinals.isEmpty)
        let pop01 = try #require(clusters.clusters.first)
        #expect(pop01.name == "Pop01")
        #expect(pop01.members.count == 100)
        #expect(abs(pop01.centroid.longitude - TestData.pop01Longitude) < 1e-6)
        #expect(abs(pop01.centroid.latitude - TestData.pop01Latitude) < 1e-6)
    }

    @Test func spacingReflectsTenMetreSampling() throws {
        for cluster in try exampleClusters().clusters {
            #expect((10...14).contains(cluster.spacing), "\(cluster.name): \(cluster.spacing) m")
        }
    }

    @Test func expandsOnlyWhenIndividualsAreAMarkerApart() throws {
        let clusters = try exampleClusters()
        let pop01 = try #require(clusters.clusters.first)
        // ~11 m spacing: collapsed at 10 m/pt, expanded at 0.5 m/pt.
        #expect(!clusters.isExpanded(pop01, metersPerPoint: 10))
        #expect(clusters.isExpanded(pop01, metersPerPoint: 0.5))
    }

    @Test func collapsedPopulationInViewContributesAllItsIndividuals() throws {
        let clusters = try exampleClusters()
        let pop01 = try #require(clusters.clusters.first)
        // A 2 km window around Pop01's centre at a zoomed-out scale.
        let side = 2_000 / MKMetersPerMapPointAtLatitude(pop01.centroid.latitude)
        let centre = MKMapPoint(pop01.centroid)
        let rect = MKMapRect(x: centre.x - side / 2, y: centre.y - side / 2, width: side, height: side)
        let viewport = MapViewport(rect: rect, width: 100)   // 20 m/pt: collapsed

        #expect(viewport.metersPerPoint > 15)
        #expect(clusters.visibleOrdinals(in: viewport) == pop01.members.map(\.ordinal).sorted())
    }

    @Test func expandedPopulationContributesOnlyIndividualsInView() throws {
        let clusters = try exampleClusters()
        let pop01 = try #require(clusters.clusters.first)
        // A 60 m window on Pop01's centre at 0.1 m/pt: expanded, and only part
        // of the ~190 m-wide population fits.
        let side = 60 / MKMetersPerMapPointAtLatitude(pop01.centroid.latitude)
        let centre = MKMapPoint(pop01.centroid)
        let rect = MKMapRect(x: centre.x - side / 2, y: centre.y - side / 2, width: side, height: side)
        let visible = clusters.visibleOrdinals(in: MapViewport(rect: rect, width: 600))

        #expect(!visible.isEmpty)
        #expect(visible.count < pop01.members.count)
    }

    @Test func onlyAdultDataWithPopulationsCollapses() throws {
        #expect(try exampleClusters().collapsesPopulations)

        let mothers = try TestData.dataset(TestData.offspringCSV())
        let motherClusters = PopulationClusters(dataset: mothers, ordinals: mothers.adultOrdinals)
        #expect(!motherClusters.collapsesPopulations)
        let cluster = try #require(motherClusters.clusters.first)
        #expect(motherClusters.isExpanded(cluster, metersPerPoint: 1_000_000))

        let unpopulated = try TestData.dataset("Latitude,Longitude,A\n37.3,-77.2,1:2\n37.4,-77.1,1:1")
        #expect(!PopulationClusters(dataset: unpopulated).collapsesPopulations)
    }

    @Test func framingShowsEveryIndividual() throws {
        let clusters = try exampleClusters()
        let frame = clusters.framingRect
        #expect(clusters.clusters.allSatisfy { frame.contains($0.boundingRect) })
    }
}
