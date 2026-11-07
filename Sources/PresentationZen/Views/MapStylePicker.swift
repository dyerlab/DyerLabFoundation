//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MapStylePicker.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A segmented Standard/Satellite control, meant to float over a map's corner.
public struct MapStylePicker: View {
    /// The selected base layer.
    @Binding public var style: MapBaseStyle

    /// Creates the picker.
    ///
    /// - Parameter style: The selected base layer.
    public init(style: Binding<MapBaseStyle>) {
        _style = style
    }

    /// The segmented control.
    public var body: some View {
        Picker("Map Style", selection: $style) {
            Text("Standard").tag(MapBaseStyle.standard)
            Text("Satellite").tag(MapBaseStyle.satellite)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .padding(8)
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var style = MapBaseStyle.standard
    MapStylePicker(style: $style)
}
