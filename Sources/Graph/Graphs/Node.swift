//
//  Node.swift
//  DyerLabFoundation
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
//  Created by Rodney Dyer on 5/21/25.
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

    /// Optional 2D layout position for non-geographic layouts.
    public var layoutCoordinate: CGPoint?
    
    public init(name: String, size: Double, color: Color = .red) {
        self.id = UUID()
        self.name = name
        self.size = size
        self.color = color
    }
    
    public init(name: String, size: Double, color: Color, coordinate: CLLocationCoordinate2D) {
        self.id = UUID()
        self.name = name
        self.size = size
        self.color = color
        self.coordinate = CLLocationCoordinate2D(latitude: coordinate.latitude,
                                                 longitude: coordinate.longitude )
        
    }
    
    
    public static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public var description: String {
        return "Node(\(name), \(size))"
    }
    
}
