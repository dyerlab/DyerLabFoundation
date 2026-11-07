//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMapView.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.10.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import MapKit
import SwiftUI
import PresentationZen

/// A map of the sampled individuals, opening on all of them.
///
/// Zoomed out, each population is one marker at its centre; zoomed in far enough to tell
/// individuals apart, it shows each individual. Clicking a population's marker zooms to that
/// population. Data without populations, and parent/offspring data, always shows each individual.
public struct GenotypeMapView: View {

    /// The populations and individuals to draw.
    public let clusters: PopulationClusters
    /// Updated as the map pans and zooms.
    @Binding public var viewport: MapViewport?

    @State private var position: MapCameraPosition
    @State private var style: MapBaseStyle = .standard

    // MARK: - Initialization

    /// Creates a map framed on every located individual.
    ///
    /// - Parameters:
    ///   - clusters: The populations and individuals to draw.
    ///   - viewport: Updated as the map pans and zooms.
    public init(clusters: PopulationClusters, viewport: Binding<MapViewport?>) {
        self.clusters = clusters
        _viewport = viewport
        _position = State(initialValue: .rect(clusters.framingRect))
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geometry in
            Map(position: $position) {
                ForEach(clusters.clusters) { cluster in
                    if isExpanded(cluster) {
                        ForEach(visibleMembers(of: cluster)) { member in
                            Annotation("", coordinate: member.coordinate, anchor: .center) {
                                IndividualMarker()
                            }
                        }
                    } else {
                        Annotation(cluster.name, coordinate: cluster.centroid, anchor: .center) {
                            PopulationMarker(count: cluster.members.count) { zoom(to: cluster) }
                        }
                    }
                }
            }
            .mapStyle(style.mapStyle)
            .mapControls {
                #if os(macOS)
                MapZoomStepper()
                #endif
                MapScaleView()
            }
            .onMapCameraChange(frequency: .continuous) { context in
                viewport = MapViewport(rect: context.rect, width: geometry.size.width)
            }
            .overlay(alignment: .topLeading) {
                MapStylePicker(style: $style)
            }
        }
    }

    private func isExpanded(_ cluster: PopulationClusters.Cluster) -> Bool {
        guard let viewport else { return !clusters.collapsesPopulations }
        return clusters.isExpanded(cluster, metersPerPoint: viewport.metersPerPoint)
    }

    /// Finds the members in view, so a zoomed-in map never carries thousands of
    /// off-screen annotations.
    ///
    /// - Parameter cluster: The population.
    /// - Returns: The members in view, or every member until the map reports its
    ///   first viewport.
    private func visibleMembers(of cluster: PopulationClusters.Cluster) -> [PopulationClusters.Member] {
        guard let viewport else { return cluster.members }
        return cluster.members.filter { viewport.rect.contains(MKMapPoint($0.coordinate)) }
    }

    /// Fits the map to a population's individuals, with a margin, or to a
    /// 200 m square around a population of one.
    ///
    /// - Parameter cluster: The population.
    private func zoom(to cluster: PopulationClusters.Cluster) {
        withAnimation {
            position = .rect(PopulationClusters.framing(cluster.boundingRect, margin: 0.25))
        }
    }
}

// MARK: - Previews

#Preview("Populations") {
    @Previewable @State var viewport: MapViewport?
    if let dataset = try? ExampleDataset.arapatPopulations.load() {
        GenotypeMapView(clusters: PopulationClusters(dataset: dataset), viewport: $viewport)
            .frame(width: 700, height: 450)
    }
}

#Preview("Mothers") {
    @Previewable @State var viewport: MapViewport?
    if let dataset = try? ExampleDataset.cornusFamilies.load() {
        GenotypeMapView(clusters: PopulationClusters(dataset: dataset, ordinals: dataset.adultOrdinals),
                        viewport: $viewport)
            .frame(width: 700, height: 450)
    }
}
