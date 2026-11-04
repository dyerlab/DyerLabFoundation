//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RasterMapRepresentable.swift
//  Graph
//
//  The `MKMapView` behind `RasterMapView`. Graph edges and nodes are drawn
//  as MapKit overlays and annotations here, rather than layering SwiftUI's
//  `Map` over the raster, so they sit above the raster rather than under it.
//  The overlay image is only rebuilt when the raster or its styling change:
//  colour-mapping millions of cells on every SwiftUI update would stall the UI.
//
//  Created by Rodney Dyer on 2026.11.03.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

#if !os(watchOS)
import MapKit
import Matrix
import SwiftUI

/// Hosts an `MKMapView` showing a raster overlay and, optionally, a graph.
@MainActor
struct RasterMapRepresentable {
    let raster: Raster
    let graph: Graph?
    let colorRamp: RasterColorRamp
    let valueRange: ClosedRange<Float>?
    let opacity: Double

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func makeMapView(coordinator: Coordinator) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = coordinator
        mapView.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .flat)
        mapView.showsScale = true
        update(mapView, coordinator: coordinator)
        let overlayRect = mapView.overlays.compactMap { $0 as? RasterOverlay }.first?.boundingMapRect
        if let overlayRect {
            mapView.setVisibleMapRect(overlayRect, edgePadding: .init(top: 24, left: 24, bottom: 24, right: 24),
                                      animated: false)
        }
        return mapView
    }

    private func update(_ mapView: MKMapView, coordinator: Coordinator) {
        let style = Coordinator.Style(raster: raster, colorRamp: colorRamp, valueRange: valueRange)
        if coordinator.style != style {
            mapView.removeOverlays(mapView.overlays.filter { $0 is RasterOverlay })
            // Insert at the bottom so graph edges stay drawn above the raster.
            mapView.insertOverlay(RasterOverlay(raster: raster, colorRamp: colorRamp, valueRange: valueRange),
                                  at: 0, level: .aboveRoads)
            coordinator.style = style
        }
        coordinator.opacity = opacity
        for overlay in mapView.overlays {
            (mapView.renderer(for: overlay) as? RasterOverlayRenderer)?.alpha = opacity
        }
        if coordinator.graphID != graph.map(ObjectIdentifier.init) {
            showGraph(on: mapView)
            coordinator.graphID = graph.map(ObjectIdentifier.init)
        }
    }

    private func showGraph(on mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays.filter { $0 is MKPolyline })
        mapView.removeAnnotations(mapView.annotations)
        guard let graph else { return }
        for edge in graph.edges {
            guard let from = graph.node(id: edge.fromNode)?.coordinate,
                  let to = graph.node(id: edge.toNode)?.coordinate else { continue }
            mapView.addOverlay(MKPolyline(coordinates: [from, to], count: 2), level: .aboveRoads)
        }
        mapView.addAnnotations(graph.nodes.compactMap { node in
            node.coordinate.map { NodeAnnotation(coordinate: $0, title: node.name, color: node.color) }
        })
    }

    // MARK: - Coordinator

    /// Draws the overlays and node markers, and remembers what's on the map to avoid redundant rebuilds.
    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {

        /// Everything the overlay image depends on.
        struct Style: Equatable {
            let raster: Raster
            let colorRamp: RasterColorRamp
            let valueRange: ClosedRange<Float>?
        }

        var style: Style?
        var opacity: Double = 1
        var graphID: ObjectIdentifier?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let raster = overlay as? RasterOverlay {
                let renderer = RasterOverlayRenderer(overlay: raster)
                renderer.alpha = opacity
                return renderer
            }
            if let line = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: line)
                renderer.strokeColor = .white.withAlphaComponent(0.8)
                renderer.lineWidth = 1.5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let node = annotation as? NodeAnnotation else { return nil }
            let identifier = "node"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKAnnotationView(annotation: node, reuseIdentifier: identifier)
            view.annotation = node
            view.canShowCallout = true
            view.frame.size = CGSize(width: 12, height: 12)
            #if os(macOS)
            view.wantsLayer = true
            guard let layer = view.layer else { return view }
            #else
            let layer = view.layer
            #endif
            layer.backgroundColor = node.color.cgColor
            layer.cornerRadius = 6
            layer.borderWidth = 1.5
            layer.borderColor = CGColor(gray: 1, alpha: 1)
            return view
        }
    }
}

// MARK: - NodeAnnotation

/// A graph node's marker on the map.
private final class NodeAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let color: Color

    init(coordinate: CLLocationCoordinate2D, title: String, color: Color) {
        self.coordinate = coordinate
        self.title = title
        self.color = color
    }
}

// MARK: - Platform hosting

#if os(macOS)
extension RasterMapRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> MKMapView {
        makeMapView(coordinator: context.coordinator)
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        update(mapView, coordinator: context.coordinator)
    }
}
#else
extension RasterMapRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> MKMapView {
        makeMapView(coordinator: context.coordinator)
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        update(mapView, coordinator: context.coordinator)
    }
}
#endif
#endif
