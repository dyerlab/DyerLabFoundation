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
//  NodeInspectorForm.swift
//  DLabPopGraph
//
//  Created by Rodney Dyer on 5/21/25.
//

import Graph
import SwiftUI
import Graph
import CoreLocation

struct NodeInspectorForm: View {
    @Environment(\.dismiss) var dismiss
    @Binding var node: Node
    
    var body: some View {
        VStack(alignment: .leading) {
            
            
            Form {
                TextField("Name", text: $node.name)
                TextField("Size", value: $node.size, formatter: NumberFormatter())
                ColorPicker("Color", selection: $node.color)
            }
            Spacer()
        }
    }
}

#if !SPM_BUILD
#Preview {
    NodeInspectorForm( node: .constant( Node( name: "BaC",
                                              size: 12.8707,
                                              color: Color.green,
                                              coordinate: CLLocationCoordinate2D( latitude: 26.59,
                                                                                  longitude: -111.79) ) ) )
}
#endif
