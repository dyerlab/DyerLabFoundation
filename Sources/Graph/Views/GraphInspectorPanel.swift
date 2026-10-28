//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphInspectorPanel.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.08.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// Right-side inspector for ``GraphLayoutView``: rendering options plus live
/// layout-physics sliders.
///
/// The physics sliders (repulsion/attraction/gravity) bind straight to
/// `orchestrator.config` via `@Bindable` rather than mirroring it in local
/// `@State` — `LayoutOrchestrator` is `@Observable`, so this keeps a single
/// source of truth and the sliders always reflect whatever preset the
/// orchestrator was created with.
public struct GraphInspectorPanel: View {

    let orchestrator: LayoutOrchestrator
    @Binding var camera: Camera2D
    @Binding var options: GraphLayoutOptions

    /// Creates the inspector.
    ///
    /// - Parameters:
    ///   - orchestrator: The layout simulation whose configuration the sliders edit.
    ///   - camera: The pan/zoom state, updated by the zoom controls.
    ///   - options: Display options, updated by the rendering sliders.
    public init(orchestrator: LayoutOrchestrator, camera: Binding<Camera2D>, options: Binding<GraphLayoutOptions>) {
        self.orchestrator = orchestrator
        self._camera = camera
        self._options = options
    }

    public var body: some View {
        @Bindable var orchestrator = orchestrator

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Inspector")
                    .font(.headline)
                Spacer()
                Button {
                    options.showInspector = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("Close Inspector")
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Layout")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Layout", selection: algorithm) {
                    ForEach(LayoutAlgorithm.allCases) { algorithm in
                        Text(algorithm.displayName).tag(algorithm)
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(budgetLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper(value: $orchestrator.iterationBudget, in: budgetRange, step: budgetStep) {
                    Text("\(orchestrator.iterationBudget)")
                        .monospacedDigit()
                }
                .help("Run length before the layout stops. If it stops while still moving, "
                      + "the control bar suggests a larger value.")
            }

            Group {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edge Width")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $options.edgeLineWidth, in: 0.5...3.0)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Node Size")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $options.nodeSizeMultiplier, in: 0.1...10.0)
                }

                // Force sliders only drive Fruchterman–Reingold.
                if orchestrator.config.algorithm == .fruchtermanReingold {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Repulsion: \(String(format: "%.1f", orchestrator.config.repulsionStrength))×")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $orchestrator.config.repulsionStrength, in: 0.1...3.0)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Attraction: \(String(format: "%.1f", orchestrator.config.attractionStrength))×")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $orchestrator.config.attractionStrength, in: 0.1...5.0)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gravity: \(String(format: "%.1f", orchestrator.config.centerGravity))×")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $orchestrator.config.centerGravity, in: 0.0...3.0)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Zoom: \(String(format: "%.1f", camera.zoom))×")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("-") {
                        camera.zoom = max(0.1, camera.zoom - 0.1)
                    }
                    .buttonStyle(.bordered)

                    Button("Reset") {
                        camera.zoom = 1.0
                        camera.pan = .zero
                    }
                    .buttonStyle(.bordered)

                    Button("+") {
                        camera.zoom = min(5.0, camera.zoom + 0.1)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
        }
        .padding()
    }

    /// Switching algorithm restarts the layout, so it goes through
    /// `setAlgorithm(_:)` rather than writing `config.algorithm` directly.
    private var algorithm: Binding<LayoutAlgorithm> {
        Binding(get: { orchestrator.config.algorithm },
                set: { orchestrator.setAlgorithm($0) })
    }

    private var isKamadaKawai: Bool { orchestrator.config.algorithm == .kamadaKawai }

    private var budgetLabel: String { isKamadaKawai ? "Moves per Node" : "Max Iterations" }

    private var budgetRange: ClosedRange<Int> { isKamadaKawai ? 10...5_000 : 100...100_000 }

    private var budgetStep: Int { isKamadaKawai ? 10 : 100 }
}

// MARK: - Previews

#Preview {
    @Previewable @State var camera = Camera2D()
    @Previewable @State var options = GraphLayoutOptions()
    let orchestrator = LayoutOrchestrator(graph: Graph.smallGraph)

    return GraphInspectorPanel(orchestrator: orchestrator, camera: $camera, options: $options)
        .frame(width: 280)
}
