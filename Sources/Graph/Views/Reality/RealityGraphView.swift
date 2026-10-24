//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  RealityGraphView.swift
//  Graph
//
//  RealityKit-based graph visualization, the long-term replacement for
//  GraphCanvasView across iOS/macOS/visionOS (GraphCanvasView is not removed
//  yet, but is being phased out — see the realitykit_unification_decision
//  project note). Two-step design: LayoutOrchestrator computes a headless
//  precompute layout (unmodified, no rendering dependency), then this view
//  hands live rendering/interaction to RealityKit's own physics.
//
//  Created by Rodney Dyer on 2026.08.09.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Combine
import RealityKit
import SwiftUI

/// SwiftUI view for visualizing a force-directed graph layout in RealityKit,
/// on iOS/macOS as a windowed 3D scene and on visionOS as a volumetric one.
public struct RealityGraphView: View {

    @State private var orchestrator: LayoutOrchestrator
    @State private var options: RealityGraphOptions
    @State private var nodeEntities: [Entity] = []
    @State private var edgeEntities: [Entity] = []
    @State private var hasSettledIntoPhysics = false
    @State private var updateSubscription: (any Cancellable)?
    @State private var draggedEntity: Entity?
    @State private var dragStartPosition: SIMD3<Float>?
    @State private var rootEntity: Entity?

    /// Creates a RealityKit graph view with default configuration.
    ///
    /// - Parameter graph: The graph to visualize
    public init(graph: Graph) {
        self.init(graph: graph, configuration: LayoutConfiguration())
    }

    /// Creates a RealityKit graph view with custom configuration.
    ///
    /// - Parameters:
    ///   - graph: The graph to visualize
    ///   - configuration: Layout algorithm parameters for the headless precompute phase
    ///   - options: Display/chrome options
    public init(graph: Graph, configuration: LayoutConfiguration, options: RealityGraphOptions = .init()) {
        _orchestrator = State(initialValue: LayoutOrchestrator(graph: graph, config: configuration))
        _options = State(initialValue: options)
    }

    public var body: some View {
        #if os(visionOS)
        RealityView { content in
            await setupScene(content: &content)
        }
        .gesture(dragGesture)
        #else
        RealityView { content in
            await setupScene(content: &content)
            content.camera = .virtual
        }
        .gesture(dragGesture)
        #endif
    }

    // MARK: - Drag interaction

    /// Picks up a node under drag by switching its `PhysicsBodyComponent` to
    /// `.kinematic` (transform-driven, ignoring incoming forces — the
    /// RealityKit-native equivalent of `LayoutOrchestrator.pinNode`), and
    /// releases it back to `.dynamic` on drag end so it rejoins the simulation
    /// (equivalent to `unpinNode`). Only meaningful post-settle, once nodes
    /// carry a `PhysicsBodyComponent` at all (`InputTargetComponent`/
    /// `CollisionComponent` are also only attached at that point, in
    /// `RealityGraphEntityBuilder.attachPhysics`), so dragging is a no-op
    /// during the precompute phase.
    ///
    /// The screen-space-to-world-space scale factor below is a first-pass
    /// approximation, not a calibrated unproject — verify/tune this against a
    /// real device or simulator run (drag gestures have no headless test path).
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .targetedToAnyEntity()
            .onChanged { value in
                let entity = value.entity
                if draggedEntity !== entity {
                    draggedEntity = entity
                    dragStartPosition = entity.position
                    entity.components[PhysicsBodyComponent.self]?.mode = .kinematic
                }
                guard let start = dragStartPosition else { return }
                let translation = value.gestureValue.translation
                let worldTranslation = SIMD3<Float>(Float(translation.width), Float(-translation.height), 0) * 0.001
                entity.position = start + worldTranslation
            }
            .onEnded { value in
                value.entity.components[PhysicsBodyComponent.self]?.mode = .dynamic
                draggedEntity = nil
                dragStartPosition = nil
            }
    }

    // MARK: - Scene setup

    /// Builds node/edge entities and starts the per-frame update subscription.
    /// Shared by both platform variants — `RealityViewContent` (visionOS) and
    /// `RealityViewCameraContent` (iOS/macOS) both conform to
    /// `RealityViewContentProtocol`, and nothing about entity construction
    /// differs between them.
    private func setupScene(content: inout some RealityViewContentProtocol) async {
        let root = Entity()
        content.add(root)
        rootEntity = root

        let nodes = RealityGraphEntityBuilder.makeNodeEntities(for: orchestrator.graph, options: options)
        let edges = RealityGraphEntityBuilder.makeEdgeEntities(for: orchestrator.graph, options: options)
        for entity in nodes { root.addChild(entity) }
        for entity in edges { root.addChild(entity) }
        nodeEntities = nodes
        edgeEntities = edges

        // Drive the headless orchestrator from RealityKit's own frame clock —
        // never orchestrator.start()/.resume(), which would spin up its own
        // internal Timer racing against this subscription.
        updateSubscription = root.scene?.subscribe(to: SceneEvents.Update.self) { [self] _ in
            frameUpdate()
        }
    }

    // MARK: - Per-frame update

    private func frameUpdate() {
        guard !hasSettledIntoPhysics else { return }

        orchestrator.step()
        if options.showPrecomputeAnimation {
            RealityGraphEntityBuilder.syncPositions(nodeEntities, from: orchestrator.state)
        }
        RealityGraphEntityBuilder.syncEdgeTransforms(edgeEntities,
                                                     graph: orchestrator.graph,
                                                     nodeEntities: nodeEntities)

        if orchestrator.isSettled {
            if !options.showPrecomputeAnimation {
                RealityGraphEntityBuilder.syncPositions(nodeEntities, from: orchestrator.state)
            }
            let joints = RealityGraphEntityBuilder.attachPhysics(nodeEntities: nodeEntities, graph: orchestrator.graph)
            // A PhysicsDistanceJoint only actually simulates once it's part of a
            // PhysicsJointsComponent on a live entity — attachPhysics only builds
            // the joint values, it doesn't activate them.
            var jointsComponent = PhysicsJointsComponent()
            jointsComponent.joints.append(contentsOf: joints)
            rootEntity?.components.set(jointsComponent)
            hasSettledIntoPhysics = true
        }
    }
}

// MARK: - Previews

#Preview("Small Graph") {
    RealityGraphView(graph: Graph.smallGraph)
}

#Preview("Lopho Graph") {
    RealityGraphView(graph: Graph.lophoGraph, configuration: .largeGraph)
}
