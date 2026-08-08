//
//  Graph.swift
//  GraphVisualization
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

/// A directed graph data structure with nodes and weighted edges.
///
/// `Graph` provides a flexible container for network data, supporting:
/// - Node management (add, lookup)
/// - Weighted directed edges with optional symmetry
/// - Shortest path computation (Dijkstra's algorithm)
/// - Graph-theoretic algorithms (centrality measures)
///
/// ## Creating a Graph
///
/// ```swift
/// let g = Graph()
/// g.addNode(name: "A", size: 1.0, color: .red)
/// g.addNode(name: "B", size: 1.0, color: .blue)
/// g.addEdge(from: "A", to: "B", weight: 2.5, symmetric: true)
/// ```
///
/// ## Computing Properties
///
/// ```swift
/// print("Nodes:", g.cardinality)
/// let path = g.shortestPath(from: "A", to: "B")
/// let centrality = BetweennessCentrality(graph: g)
/// ```
///
/// - Note: Edges are directed. Use `symmetric: true` when adding edges to create bidirectional connections.
public class Graph: Identifiable, Hashable  {
    public var id: UUID
    public var nodes: [Node]
    public var edges: [Edge]

    public init(nodes: [Node] = [] , edges: [Edge] = []) {
        self.id = UUID()
        self.nodes = nodes
        self.edges = edges
    }
    
    /// The number of nodes in the graph.
    public var cardinality: Int {
        return nodes.count
    }
    
    public static func == (lhs: Graph, rhs: Graph) -> Bool {
        return lhs.id == rhs.id
    }
    
    /// Finds a node by name.
    ///
    /// - Parameter name: The name of the node to find
    /// - Returns: The matching node, or `nil` if not found
    public func node(name: String ) -> Node? {
        return nodes.first(where: { $0.name == name })
    }

    /// Finds a node by unique identifier.
    ///
    /// - Parameter id: The UUID of the node to find
    /// - Returns: The matching node, or `nil` if not found
    public func node(id: UUID ) -> Node? {
        return nodes.first(where: { $0.id == id })
    }
        
    /// Adds a new node to the graph.
    ///
    /// - Parameters:
    ///   - name: The node's label
    ///   - size: Visual size (used for rendering)
    ///   - color: Visual color (used for rendering)
    public func addNode(name: String, size: Double, color: Color,
                         categoricalAttributes: [String: String] = [:], continuousAttributes: [String: Double] = [:] ) {
        nodes.append( Node(name: name, size: size, color: color,
                            categoricalAttributes: categoricalAttributes, continuousAttributes: continuousAttributes) )
    }

    /// Adds a new node with geographic coordinates.
    ///
    /// - Parameters:
    ///   - name: The node's label
    ///   - size: Visual size (used for rendering)
    ///   - color: Visual color (used for rendering)
    ///   - coordinate: Geographic location (latitude/longitude)
    ///   - categoricalAttributes: Open-ended string-valued attributes (e.g. `"Region": "1"`)
    ///   - continuousAttributes: Open-ended real-valued attributes (e.g. `"elevation": 125.3`)
    public func addNode(name: String, size: Double, color: Color, coordinate: CLLocationCoordinate2D,
                         categoricalAttributes: [String: String] = [:], continuousAttributes: [String: Double] = [:] ) {
        nodes.append( Node(name: name, size: size, color: color, coordinate: coordinate,
                            categoricalAttributes: categoricalAttributes, continuousAttributes: continuousAttributes) )
    }
    
    
    /// Adds a directed edge between nodes identified by name.
    ///
    /// - Parameters:
    ///   - from: Name of the source node
    ///   - to: Name of the target node
    ///   - weight: Edge weight (default: 1.0)
    ///   - symmetric: If `true`, also adds the reverse edge (default: false)
    ///
    /// If either node is not found, the edge is not added.
    ///
    /// ## Example
    /// ```swift
    /// g.addEdge(from: "A", to: "B", weight: 2.5, symmetric: true)
    /// // Creates edges A→B and B→A, both with weight 2.5
    /// ```
    public func addEdge( from: String, to: String, weight: Double, symmetric: Bool ) {
        if let node1 = self.node(name: from),
           let node2 = self.node(name: to) {
            self.addEdge(from: node1, to: node2, weight: weight, symmetric: symmetric)
        }
    }
    
    
    public func addEdge( from: Node, to: Node, weight: Double = 1.0, symmetric: Bool ) {
        edges.append( Edge(fromNode: from, toNode: to, weight: weight ) )
        if symmetric {
            edges.append( Edge(fromNode: to, toNode: from, weight: weight ) )
        }
    }
    
    public func nodesForEdge(_ edge: Edge) -> [Node]? {
        if let node1 = nodes.first(where: { $0.id == edge.fromNode } ),
           let node2 = nodes.first(where: { $0.id == edge.toNode } ) {
            return [node1,node2]
        }
        return nil
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    
    /// Convience function to pass node names instead of node objects.
    /// - Returns: Path for the shortest path or nil i fno path exists
    public func shortestPath( from: String, to: String) -> Path? {
        if let node1 = self.node(name: from),
           let node2 = self.node(name: to) {
            return self.shortestPath(from: node1, to: node2)
        } else {
            return nil
        }
    }
    
    /// Implements Dijkstra's algorithm for shortest path in a directed graph with non-negative edge weights.
    /// - Returns: Path object for the shortest path, or nil if no path exists.
    public func shortestPath(from start: Node, to end: Node) -> Path? {
        var distances = [UUID: Double]()
        var previous = [UUID: UUID]()
        var unvisited = Set(nodes.map { $0.id })

        for node in nodes {
            distances[node.id] = Double.infinity
        }
        distances[start.id] = 0

        while let current = unvisited.min(by: { (distances[$0] ?? Double.infinity) < (distances[$1] ?? Double.infinity) }) {
            // If the closest remaining node is unreachable (infinite distance),
            // then so is every other unvisited node — including the destination.
            // Stop and report no path rather than returning a bogus ∞-distance
            // path, which would otherwise corrupt closeness/betweenness on
            // disconnected or directed graphs.
            if (distances[current] ?? Double.infinity).isInfinite { break }

            unvisited.remove(current)

            if current == end.id {
                var pathNodes: [Node] = []
                var nodeID: UUID? = end.id
                while let id = nodeID {
                    if let node = nodes.first(where: { $0.id == id }) {
                        pathNodes.insert(node, at: 0)
                    }
                    nodeID = previous[id]
                }
                var path = Path(source: start, destination: end)
                path.sequence = pathNodes
                path.distance = distances[end.id] ?? Double.infinity
                return path
            }

            let neighbors = edges.filter { $0.fromNode == current && unvisited.contains($0.toNode) }
            for edge in neighbors {
                let alt = (distances[current] ?? Double.infinity) + edge.weight
                if alt < (distances[edge.toNode] ?? Double.infinity) {
                    distances[edge.toNode] = alt
                    previous[edge.toNode] = current
                }
            }
        }

        return nil
    }
    
    
}





public extension Graph {

    /// Initializes all nodes with random layout positions within the specified bounds.
    ///
    /// This method assigns random `layoutCoordinate` values to all nodes in the graph,
    /// which is typically the first step before running a force-directed layout algorithm.
    ///
    /// - Parameter bounds: The bounding rectangle for random placement
    ///
    /// ## Example
    /// ```swift
    /// let graph = Graph.smallGraph
    /// graph.initializeRandomLayout(in: CGRect(x: 0, y: 0, width: 500, height: 500))
    /// let simulation = LayoutSimulation(graph: graph)
    /// simulation.start()
    /// ```
    func initializeRandomLayout(in bounds: CGRect) {
        var generator = SystemRandomNumberGenerator()
        initializeRandomLayout(in: bounds, using: &generator)
    }

    /// Initializes all nodes with random layout positions using a caller-supplied generator.
    ///
    /// Supplying a deterministic generator (e.g. a seeded one) makes the resulting
    /// layout reproducible, which is useful for tests.
    ///
    /// - Parameters:
    ///   - bounds: The bounding rectangle for random placement
    ///   - generator: The random number generator to draw positions from
    func initializeRandomLayout<G: RandomNumberGenerator>(in bounds: CGRect, using generator: inout G) {
        for node in nodes {
            node.layoutCoordinate = CGPoint(
                x: Double.random(in: bounds.minX...bounds.maxX, using: &generator),
                y: Double.random(in: bounds.minY...bounds.maxY, using: &generator)
            )
        }
    }

    /// Computes the bounding box of current layout positions.
    ///
    /// Returns the smallest rectangle that contains all nodes with `layoutCoordinate` values.
    /// Useful for auto-scaling visualizations or determining canvas size.
    ///
    /// - Returns: The bounding rectangle, or `nil` if no nodes have layout coordinates
    ///
    /// ## Example
    /// ```swift
    /// if let bounds = graph.layoutBoundingBox() {
    ///     print("Graph spans \(bounds.width) × \(bounds.height)")
    /// }
    /// ```
    func layoutBoundingBox() -> CGRect? {
        let positions = nodes.compactMap { $0.layoutCoordinate }
        guard !positions.isEmpty else { return nil }

        let minX = positions.map { $0.x }.min() ?? 0
        let maxX = positions.map { $0.x }.max() ?? 0
        let minY = positions.map { $0.y }.min() ?? 0
        let maxY = positions.map { $0.y }.max() ?? 0

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    static var smallGraph: Graph {
        let g = Graph()
        
        g.addNode(name: "A", size: 1.0, color: .red )
        g.addNode(name: "B", size: 1.0, color: .green )
        g.addNode(name: "C", size: 1.5, color: .blue )
        g.addNode(name: "D", size: 2.0, color: .orange )
        
        g.addEdge(from: "A", to: "B", weight: 1.0, symmetric: true )
        g.addEdge(from: "B", to: "C", weight: 2.0, symmetric: true )
        g.addEdge(from: "C", to: "A", weight: 3.0, symmetric: true )
        g.addEdge(from: "C", to: "D", weight: 4.0, symmetric: false )
        
        return g
    }
    
    /// The Lophocereus schottii (senita cactus) population graph: 21 sampled
    /// populations across the Baja California / Sonoran Desert range, spatially
    /// located with genetic-distance-weighted edges.
    ///
    /// Loaded from the bundled `Data/lopho.geojson` resource — a build-time
    /// invariant, so a missing/malformed resource here is a packaging bug,
    /// not a runtime condition callers need to handle.
    static var lophoGraph: Graph {
        let url = try! GraphExampleData.url("lopho", extension: "geojson")
        return try! Graph.importGeoJSON(contentsOf: url)
    }

}



