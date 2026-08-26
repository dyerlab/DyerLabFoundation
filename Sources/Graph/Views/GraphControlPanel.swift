//
//  GraphControlPanel.swift
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

import SwiftUI

/// Bottom control bar for ``GraphLayoutView``: simulation stats, play/pause/
/// reset/reheat/fit, and the node-label toggle.
public struct GraphControlPanel: View {

    let orchestrator: LayoutOrchestrator
    @Binding var camera: Camera2D
    @Binding var options: GraphLayoutOptions

    public init(orchestrator: LayoutOrchestrator, camera: Binding<Camera2D>, options: Binding<GraphLayoutOptions>) {
        self.orchestrator = orchestrator
        self._camera = camera
        self._options = options
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Stats row
            HStack(spacing: 20) {
                Label("Iteration: \(orchestrator.iteration)", systemImage: "number")
                    .font(.caption)

                Label("Temp: \(String(format: "%.1f", orchestrator.temperature))", systemImage: "thermometer")
                    .font(.caption)

                Label("Energy: \(String(format: "%.2f", orchestrator.kineticEnergy))", systemImage: "bolt.fill")
                    .font(.caption)

                if orchestrator.isSettled {
                    Label("Settled", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Spacer()
            }

            Divider()

            // Control buttons
            HStack(spacing: 16) {
                Button(action: {
                    if orchestrator.isRunning {
                        orchestrator.stop()
                    } else {
                        orchestrator.start()
                    }
                }) {
                    Label(
                        orchestrator.isRunning ? "Pause" : "Start",
                        systemImage: orchestrator.isRunning ? "pause.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    orchestrator.reset()
                    orchestrator.start()
                }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    orchestrator.reheat()
                }) {
                    Label("Reheat", systemImage: "flame")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    camera = fitToView(state: orchestrator.state, canvasSize: CGSize(width: 600, height: 600))
                }) {
                    Label("Fit", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.bordered)

                // Label toggle
                Toggle(isOn: $options.showLabels) {
                    Label("Labels", systemImage: "textformat")
                        .font(.caption)
                }
                .toggleStyle(.button)

                Spacer()
            }
        }
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var camera = Camera2D()
    @Previewable @State var options = GraphLayoutOptions()
    let orchestrator = LayoutOrchestrator(graph: Graph.smallGraph)

    return GraphControlPanel(orchestrator: orchestrator, camera: $camera, options: $options)
        .padding()
}
