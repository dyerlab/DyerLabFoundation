//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PlotStyle.swift
//  PresentationZenCore
//
//  Figures and in-app charts want different chrome: a figure carries large axis titles and a minimum height, while
//  a chart in a list row or card is sized by its container and labels its axes only when asked.
//
//  Created by Rodney Dyer on 2026.11.20.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// How much chrome a chart draws around its marks.
public enum PlotStyle: Hashable, Sendable {
    /// A stand-alone figure: large axis titles (inferred when empty) and a minimum height.
    case figure
    /// A chart inside an app screen: small axis titles only when given, grid lines, and no minimum height,
    /// so the caller sets the frame.
    case compact
    /// A sparkline: the marks alone, with no axes, grid lines, titles or labels; the caller sets the frame.
    case sparkline
}
