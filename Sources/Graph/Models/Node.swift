//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Node.swift
//  Graph
//
//  Created by Rodney Dyer on 2025.05.21.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix
import SwiftUI
import Foundation
import CoreLocation

/// A node (vertex) in a graph.
///
/// Represents a single node with a unique identifier, label, and visual properties.
/// Can optionally include geographic coordinates for spatial graphs.
///
/// ## Example
/// ```swift
/// let node = Node(name: "PopulationA", size: 10.0, color: .blue)
/// node.coordinate = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4)
/// ```
public class Node: Identifiable, Equatable, Hashable, CustomStringConvertible {

    /// Unique identifier for the node.
    public var id: UUID

    /// The node's label or name.
    public var name: String

    /// Visual size for rendering (e.g., in graph visualizations).
    public var size: Double

    /// Visual color for rendering.
    public var color: Color

    /// Optional geographic coordinate (latitude/longitude).
    public var coordinate: CLLocationCoordinate2D?

    /// Open-ended categorical (string-valued) attributes, keyed by name
    /// (e.g. `"Region": "1"`). Populated by file importers for whatever
    /// classification columns/properties the source data happens to carry.
    public var categoricalAttributes: [String: String]

    /// Open-ended continuous (real-valued) attributes, keyed by name
    /// (e.g. `"elevation": 125.3`).
    public var continuousAttributes: [String: Double]

    /// Creates a node with no coordinate.
    ///
    /// - Parameters:
    ///   - name: The node's label.
    ///   - size: The node's visual size.
    ///   - color: The node's visual color (default `.red`).
    ///   - categoricalAttributes: Categorical attributes by name.
    ///   - continuousAttributes: Continuous attributes by name.
    public init(name: String, size: Double, color: Color = .red,
                categoricalAttributes: [String: String] = [:], continuousAttributes: [String: Double] = [:]) {
        self.id = UUID()
        self.name = name
        self.size = size
        self.color = color
        self.categoricalAttributes = categoricalAttributes
        self.continuousAttributes = continuousAttributes
    }

    /// Creates a node at a geographic coordinate.
    ///
    /// - Parameters:
    ///   - name: The node's label.
    ///   - size: The node's visual size.
    ///   - color: The node's visual color.
    ///   - coordinate: The node's latitude and longitude.
    ///   - categoricalAttributes: Categorical attributes by name.
    ///   - continuousAttributes: Continuous attributes by name.
    public init(name: String, size: Double, color: Color, coordinate: CLLocationCoordinate2D,
                categoricalAttributes: [String: String] = [:], continuousAttributes: [String: Double] = [:]) {
        self.id = UUID()
        self.name = name
        self.size = size
        self.color = color
        self.coordinate = CLLocationCoordinate2D(latitude: coordinate.latitude,
                                                 longitude: coordinate.longitude)
        self.categoricalAttributes = categoricalAttributes
        self.continuousAttributes = continuousAttributes
    }

    public static func == (lhs: Node, rhs: Node) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public var description: String {
        "Node(\(name), \(size))"
    }

}
