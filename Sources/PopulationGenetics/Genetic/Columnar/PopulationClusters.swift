//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PopulationClusters.swift
//  PopulationGenetics
//
//  The map draws each population as one marker at its centre until its
//  individuals would be distinguishable on screen: a population expands once
//  its typical nearest-neighbour spacing covers at least one marker's width.
//  Each population decides independently, so neighbouring populations can be
//  collapsed while the one in view is expanded. Only adult data with
//  populations collapses: without populations there is nothing to collapse
//  into, and in parent/offspring data each mother is her own entity.
//
//  Created by Rodney Dyer on 2026.10.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import MapKit
import PresentationZen

/// The individuals of a dataset grouped by population, for the map.
public struct PopulationClusters: Sendable {

    /// One individual with coordinates.
    public struct Member: Identifiable, Sendable {
        /// The individual's row in the genotype matrix.
        public let ordinal: Int
        /// The individual's location.
        public let coordinate: CLLocationCoordinate2D

        /// The individual's row in the genotype matrix.
        public var id: Int { ordinal }
    }

    /// One population's located individuals.
    public struct Cluster: Identifiable, Sendable {
        /// The population's name.
        public let name: String
        /// The mean location of the population's individuals.
        public let centroid: CLLocationCoordinate2D
        /// The population's individuals that have coordinates.
        public let members: [Member]
        /// The median distance from each individual to its nearest neighbour, in
        /// metres; `0` for a population of one.
        public let spacing: CLLocationDistance

        /// The population's name.
        public var id: String { name }

        /// The smallest map rectangle holding every member.
        public var boundingRect: MKMapRect {
            members.reduce(MKMapRect.null) { rect, member in
                rect.union(MKMapRect(origin: MKMapPoint(member.coordinate), size: MKMapSize(width: 0, height: 0)))
            }
        }
    }

    /// The marker width, in points, that individuals must be apart before a
    /// population is drawn as separate individuals.
    public static let markerSize: Double = 12

    /// Populations with at least one located individual, in natural sort order.
    public let clusters: [Cluster]

    /// Rows of individuals without coordinates; they never appear on the map.
    public let unlocatedOrdinals: [Int]

    /// The rows of the individuals grouped, in ascending order.
    public let ordinals: [Int]

    /// Whether populations collapse into one marker when zoomed out.
    ///
    /// When `false`, every individual is always drawn on its own.
    public let collapsesPopulations: Bool

    /// The number of individuals grouped.
    public var individualCount: Int { ordinals.count }

    /// Whether any individual has coordinates.
    public var isSpatial: Bool { !clusters.isEmpty }

    /// Groups a dataset's individuals by population.
    ///
    /// - Parameters:
    ///   - dataset: The genotypes, with strata and coordinates.
    ///   - ordinals: The rows to group, or `nil` for every individual.
    public init(dataset: ImportedDataset, ordinals: [Int]? = nil) {
        let ordinals = ordinals ?? Array(0..<dataset.matrix.individualCount)
        var byPopulation: [String: [Member]] = [:]
        var unlocated: [Int] = []
        for ordinal in ordinals {
            let individual = dataset.matrix.individuals[ordinal]
            guard let latitude = individual.latitude, let longitude = individual.longitude else {
                unlocated.append(ordinal)
                continue
            }
            let member = Member(ordinal: ordinal,
                                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            byPopulation[dataset.populationName(at: ordinal), default: []].append(member)
        }
        clusters = byPopulation.keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { name in
                let members = byPopulation[name] ?? []
                let count = Double(members.count)
                let centroid = CLLocationCoordinate2D(
                    latitude: members.map(\.coordinate.latitude).reduce(0, +) / count,
                    longitude: members.map(\.coordinate.longitude).reduce(0, +) / count)
                return Cluster(name: name, centroid: centroid, members: members,
                               spacing: Self.medianNearestNeighbourDistance(members))
            }
        unlocatedOrdinals = unlocated
        self.ordinals = ordinals
        collapsesPopulations = dataset.parentage.families.isEmpty && dataset.hasPopulations
    }

    /// Whether a population's individuals are far enough apart on screen to
    /// draw separately.
    ///
    /// - Parameters:
    ///   - cluster: The population.
    ///   - metersPerPoint: The map's current scale.
    /// - Returns: `true` when the population should show individual markers.
    public func isExpanded(_ cluster: Cluster, metersPerPoint: Double) -> Bool {
        !collapsesPopulations || (cluster.spacing > 0 && cluster.spacing / metersPerPoint >= Self.markerSize)
    }

    /// A map rectangle showing every located individual, with a margin.
    public var framingRect: MKMapRect {
        Self.framing(clusters.reduce(MKMapRect.null) { $0.union($1.boundingRect) }, margin: 0.1)
    }

    /// Pads a map rectangle by a fraction of its size on each side, and widens
    /// it to at least 200 m across so a single point isn't shown at street level.
    ///
    /// - Parameters:
    ///   - rect: The rectangle to frame.
    ///   - margin: The padding on each side, as a fraction of the rectangle's width and height.
    /// - Returns: The padded rectangle.
    public static func framing(_ rect: MKMapRect, margin: Double) -> MKMapRect {
        let latitude = MKMapPoint(x: rect.midX, y: rect.midY).coordinate.latitude
        let minimumSide = 200 / MKMetersPerMapPointAtLatitude(latitude)
        return rect.insetBy(dx: -max(rect.width * margin, (minimumSide - rect.width) / 2),
                            dy: -max(rect.height * margin, (minimumSide - rect.height) / 2))
    }

    /// The rows the map is showing: every individual of a collapsed population whose centre is in
    /// view, and each individual of an expanded population that is itself in view.
    ///
    /// Individuals without coordinates are always included.
    ///
    /// - Parameter viewport: The map's visible area and scale.
    /// - Returns: Matrix rows, in ascending order.
    public func visibleOrdinals(in viewport: MapViewport) -> [Int] {
        var ordinals = unlocatedOrdinals
        for cluster in clusters {
            if isExpanded(cluster, metersPerPoint: viewport.metersPerPoint) {
                ordinals += cluster.members
                    .filter { viewport.rect.contains(MKMapPoint($0.coordinate)) }
                    .map(\.ordinal)
            } else if viewport.rect.contains(MKMapPoint(cluster.centroid)) {
                ordinals += cluster.members.map(\.ordinal)
            }
        }
        return ordinals.sorted()
    }

    /// Finds the median nearest-neighbour distance, using a local flat-earth
    /// projection (accurate to well under a percent across a population's extent).
    ///
    /// - Parameter members: The population's located individuals.
    /// - Returns: The distance in metres, or `0` for a population of one.
    private static func medianNearestNeighbourDistance(_ members: [Member]) -> CLLocationDistance {
        guard members.count > 1 else { return 0 }
        let metresPerDegree = 111_320.0
        let points = members.map { member in
            (x: member.coordinate.longitude * metresPerDegree * cos(member.coordinate.latitude * .pi / 180),
             y: member.coordinate.latitude * metresPerDegree)
        }
        let nearest = points.indices.map { i in
            points.indices.lazy
                .filter { $0 != i }
                .map { j in hypot(points[i].x - points[j].x, points[i].y - points[j].y) }
                .min() ?? 0
        }
        return nearest.sorted()[nearest.count / 2]
    }
}
