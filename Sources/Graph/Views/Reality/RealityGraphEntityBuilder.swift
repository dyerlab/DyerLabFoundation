//
//  RealityGraphEntityBuilder.swift
//  DyerlabFoundation
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
//  Platform-agnostic RealityKit entity construction shared by RealityGraphView's
//  visionOS and iOS/macOS variants. Nothing here depends on which RealityView
//  content type is hosting these entities — only entity/component/scene-graph
//  APIs, which are identical across platforms; the platform split lives entirely
//  in RealityGraphView itself.
//

import RealityKit
import SwiftUI

/// Builds and updates the RealityKit entities behind ``RealityGraphView``.
///
/// No `@available` gating needed here or elsewhere in `Sources/Graph/Views/Reality/` —
/// `Package.swift`'s platform floor (iOS 18/macOS 15/visionOS 2) already exactly matches
/// what `RealityView`/`PhysicsDistanceJoint` require, so every symbol in this package is
/// already guaranteed to run on a new-enough OS.
@MainActor
enum RealityGraphEntityBuilder {

    /// Carries the sphere radius an entity was created with, so `attachPhysics`
    /// can size a matching collision shape without re-deriving it from mesh bounds.
    private struct NodeRadiusComponent: Component {
        var radius: Float
    }

    /// Creates one `ModelEntity` per `graph.nodes` entry (same order — callers
    /// pair these up with `Graph.nodeIndices()` for edge wiring), sized/colored
    /// from each `Node`, with no physics or interaction components yet.
    static func makeNodeEntities(for graph: Graph, options: RealityGraphOptions) -> [Entity] {
        graph.nodes.map { node in
            let radius = max(Float(node.size * options.nodeSizeMultiplier), 0.001)
            let mesh = MeshResource.generateSphere(radius: radius)
            let material = SimpleMaterial(color: platformColor(from: node.color), isMetallic: false)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.name = node.name
            entity.components.set(NodeRadiusComponent(radius: radius))
            return entity
        }
    }

    /// Positions each node entity from `LayoutState.positions` — the precompute-phase
    /// visual, before physics takes ownership of position.
    static func syncPositions(_ entities: [Entity], from state: LayoutState) {
        for index in entities.indices where index < state.positions.count {
            entities[index].position = state.positions[index]
        }
    }

    /// Creates one thin cylinder `ModelEntity` per `graph.edges` entry (same
    /// order — pair with `syncEdgeTransforms` using this same array). RealityKit
    /// has no built-in line primitive, so edges need actual mesh geometry, unlike
    /// `GraphCanvasView`'s cheap immediate-mode line drawing.
    static func makeEdgeEntities(for graph: Graph, options: RealityGraphOptions) -> [Entity] {
        let material = SimpleMaterial(color: platformColor(from: .gray), isMetallic: false)
        return graph.edges.map { _ in
            let mesh = MeshResource.generateCylinder(height: 1.0, radius: options.edgeThickness)
            return ModelEntity(mesh: mesh, materials: [material])
        }
    }

    /// Repositions/reorients each edge entity between its two node entities.
    /// `edgeEntities` and `graph.edges` must be the same length and order (as
    /// produced by a corresponding entity-creation pass, not built here).
    static func syncEdgeTransforms(_ edgeEntities: [Entity], graph: Graph, nodeEntities: [Entity]) {
        let nodeIndices = graph.nodeIndices()
        for (edgeIndex, edge) in graph.edges.enumerated() where edgeIndex < edgeEntities.count {
            guard let i = nodeIndices[edge.fromNode], let j = nodeIndices[edge.toNode],
                  i < nodeEntities.count, j < nodeEntities.count else { continue }
            let from = nodeEntities[i].position
            let to = nodeEntities[j].position
            let edgeEntity = edgeEntities[edgeIndex]
            edgeEntity.position = (from + to) / 2
            let delta = to - from
            let length = simd_length(delta)
            guard length > 0.0001 else { continue }
            edgeEntity.scale.y = length
            edgeEntity.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(delta))
        }
    }

    /// One-time transition from the headless precompute phase to live physics:
    /// attaches `PhysicsBodyComponent`/`CollisionComponent`/`InputTargetComponent`
    /// to each node entity (sized from the radius recorded in `makeNodeEntities`),
    /// then builds one `PhysicsDistanceJoint` per edge — resolving endpoints via
    /// `Graph.nodeIndices()` (O(1) per edge), not `node(id:)` + `firstIndex(of:)`.
    /// Callers are responsible for actually activating the returned joints (e.g.
    /// via a `PhysicsJointsComponent` on a shared ancestor entity).
    ///
    /// Each joint's rest length is the edge's length *in the settled layout*,
    /// read from the entities' current positions — not a formula like
    /// `weight × k`. A real distance-weighted graph can't satisfy every edge
    /// length at once, so the precompute settles on a compromise; taking that
    /// compromise as the rest state means physics starts in equilibrium (no snap
    /// at handoff) and preserves whichever layout produced it, Fruchterman–Reingold
    /// or Kamada–Kawai alike.
    @discardableResult
    static func attachPhysics(nodeEntities: [Entity], graph: Graph) -> [PhysicsDistanceJoint] {
        for entity in nodeEntities {
            let radius = entity.components[NodeRadiusComponent.self]?.radius ?? 0.01
            entity.components.set(PhysicsBodyComponent(massProperties: .default, material: nil, mode: .dynamic))
            entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: radius)]))
            entity.components.set(InputTargetComponent())
        }

        let nodeIndices = graph.nodeIndices()
        var joints: [PhysicsDistanceJoint] = []
        joints.reserveCapacity(graph.edges.count)
        for (edgeIndex, edge) in graph.edges.enumerated() {
            guard let i = nodeIndices[edge.fromNode], let j = nodeIndices[edge.toNode],
                  i < nodeEntities.count, j < nodeEntities.count else { continue }
            let restLength = simd_distance(nodeEntities[i].position, nodeEntities[j].position)
            let pin0 = nodeEntities[i].pins.set(named: "edge\(edgeIndex).from", position: .zero)
            let pin1 = nodeEntities[j].pins.set(named: "edge\(edgeIndex).to", position: .zero)
            let joint = PhysicsDistanceJoint(pin0: pin0, pin1: pin1,
                                              distanceLimit: edgeDistanceLimit(idealLength: restLength, tolerance: 0.05))
            joints.append(joint)
        }
        return joints
    }

    /// The distance range a `PhysicsDistanceJoint` should hold an edge to: a
    /// small band around `idealLength` (rather than a single fixed value) so the
    /// joint has a little spring-like give instead of behaving as a rigid rod.
    /// Pure function — no RealityKit dependency, trivially unit-testable.
    static func edgeDistanceLimit(idealLength: Float, tolerance: Float) -> ClosedRange<Float> {
        let lower = idealLength * (1 - tolerance)
        let upper = idealLength * (1 + tolerance)
        return min(lower, upper)...max(lower, upper)
    }
}

/// Converts a SwiftUI `Color` to RealityKit's `Material.Color` (`UIColor` on
/// iOS/visionOS, `NSColor` on macOS — a nested typealias on `Material`, not a
/// standalone `RealityKit.Color` type) via `Color.Resolved`'s linear RGB
/// components. `Material.Color`'s underlying type always has a matching
/// `init(red:green:blue:alpha:)`, so this needs no platform branching.
private func platformColor(from color: SwiftUI.Color) -> RealityKit.Material.Color {
    let resolved = color.resolve(in: EnvironmentValues())
    return RealityKit.Material.Color(red: CGFloat(resolved.red), green: CGFloat(resolved.green),
                                      blue: CGFloat(resolved.blue), alpha: CGFloat(resolved.opacity))
}
