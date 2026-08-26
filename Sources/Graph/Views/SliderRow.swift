//
//  SliderRow.swift
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

/// A labeled slider row: a caption above a `Slider`, used by ``GraphInspectorPanel``
/// for its rendering/physics sliders.
struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Slider(value: $value, in: range)
        }
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var value = 1.5
    return SliderRow(label: "Example", value: $value, range: 0.0...3.0)
        .padding()
}
