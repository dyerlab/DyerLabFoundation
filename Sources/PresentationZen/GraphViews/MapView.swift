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
//  MapView.swift
//  DLabPopGraph
//
//  Created by Rodney Dyer on 5/21/25.
//

import Graph
import SwiftUI
import Graph
import MapKit


public struct MapView: View {
    @Binding public var graph: Graph
    @Binding public var lineWidth: CGFloat
    @Binding public var nodeScaling: CGFloat
    
    @State private var selectedNodeID: UUID? = nil
    @State private var isPresentingInspector: Bool = false
    
    public var body: some View {
        
        
        Map {
            
            // Lay out the edges
            ForEach( graph.edges, id: \.self) { edge in
                if let pt1 = graph.node(id: edge.fromNode)?.coordinate,
                   let pt2 = graph.node(id: edge.toNode)?.coordinate {
                    MapPolyline(coordinates: [pt1, pt2])
                        .stroke(.gray, lineWidth: lineWidth)
                }
            }
            
            // Lay out the nodes
            ForEach( graph.nodes, id: \.self) { node in
                if let coord = node.coordinate {
                    Annotation(node.name,
                               coordinate: coord ) {
                        Button(action: {
                            selectedNodeID = node.id
                            isPresentingInspector = true
                        }) {
                            Circle()
                                .fill(node.color)
                                .scaleEffect(node.size / nodeScaling)
                        }
                        .buttonStyle(.plain) // Avoids any button styling
                    }
                }
            }
        }
        .mapStyle( MapStyle.hybrid )
        .mapControls {
            MapScaleView()
            MapCompass()
            MapPitchToggle()
            
            #if os(macOS)
            MapZoomStepper()
            MapPitchSlider()
            #endif 
        }
        .inspector(isPresented: $isPresentingInspector ) {
            if let index = graph.nodes.firstIndex(where: { $0.id == selectedNodeID }) {
                NodeInspectorForm(node: $graph.nodes[index])
            }
        }
        
        
    }
}


enum MapStyleOption: String, CaseIterable, Hashable {
    case standard, imagery, hybrid
    
    var mapStyle: MapStyle {
        switch self {
        case .standard:
            return .standard(elevation: .realistic)
        case .imagery:
            return .imagery(elevation: .realistic)
        case .hybrid:
            return .hybrid(elevation: .realistic)
        }
    }
}





#if !SPM_BUILD
#Preview {
    MapView(
        graph: .constant( Graph.lophoGraph ),
        lineWidth: .constant( 1.0 ),
        nodeScaling: .constant( 10.0 )
    )
}
#endif


