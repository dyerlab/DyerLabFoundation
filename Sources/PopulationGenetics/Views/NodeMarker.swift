//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  NodeMarker.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// A population graph node's map marker, sized by within-population variance.
public struct NodeMarker: View {
    /// The node's within-population variance.
    public let size: Double

    /// Creates a marker.
    ///
    /// - Parameter size: The node's within-population variance.
    public init(size: Double) {
        self.size = size
    }

    public var body: some View {
        let diameter = 8 + 1.5 * max(size, 0)
        Circle()
            .fill(.tint)
            .stroke(.white, lineWidth: 1.5)
            .frame(width: diameter, height: diameter)
    }
}

// MARK: - Previews

#Preview("Small and large") {
    HStack(spacing: 20) {
        NodeMarker(size: 2)
        NodeMarker(size: 14)
    }
    .padding()
}
