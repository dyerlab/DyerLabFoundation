//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  View+FigureFrame.swift
//  PresentationZen
//
//  A chart stretched to fill a window is distorted by the window's shape: a scatter in a wide window flattens its
//  slope, and a density in a tall one exaggerates its peak. Pages give their charts this frame instead, so a chart
//  keeps the proportions of a printed figure and sits centred with space around it, whatever the window.
//
//  Created by Rodney Dyer on 2026.11.09.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

public extension View {

    /// Frames a chart as a figure: a fixed aspect ratio, no wider than a page figure, centred with space around it.
    ///
    /// - Parameters:
    ///   - aspectRatio: Width over height (default `1.6`).
    ///   - maxWidth: The widest it is drawn, in points (default `760`).
    /// - Returns: The framed chart.
    func figureFrame(aspectRatio: CGFloat = 1.6, maxWidth: CGFloat = 760) -> some View {
        self
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxWidth: maxWidth)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
    }
}
