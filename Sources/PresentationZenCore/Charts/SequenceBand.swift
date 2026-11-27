//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  SequenceBand.swift
//  PresentationZenCore
//
//  A stretch of a sequence that belongs together (a version, a phase, a method), drawn behind the marks.
//
//  Created by Rodney Dyer on 2026.11.27.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A span of positions in a ``SequencePlot``, shaded behind its marks.
public struct SequenceBand: Hashable, Identifiable, Sendable {
    /// Where the band starts; usually half a step before its first position.
    public var start: Double
    /// Where the band ends; usually half a step after its last position.
    public var end: Double
    /// A short label drawn at the band's top leading corner, or `nil` for none.
    public var label: String?
    /// Whether the band is filled; alternate bands are left clear so neighbors stand apart.
    public var isShaded: Bool

    /// The band's place on the axis.
    public var id: Double { start }

    /// Creates a band.
    ///
    /// - Parameters:
    ///   - start: Where the band starts.
    ///   - end: Where the band ends.
    ///   - label: A short label for the band, or `nil`.
    ///   - isShaded: Whether the band is filled.
    public init(start: Double, end: Double, label: String? = nil, isShaded: Bool = true) {
        self.start = start
        self.end = end
        self.label = label
        self.isShaded = isShaded
    }

    /// The band covering whole positions `first` through `last`, from half a step before to half a step after.
    ///
    /// - Parameters:
    ///   - first: The first position in the band.
    ///   - last: The last position in the band.
    ///   - label: A short label for the band, or `nil`.
    ///   - isShaded: Whether the band is filled.
    /// - Returns: The band.
    public static func covering(_ first: Int, through last: Int, label: String? = nil,
                                isShaded: Bool = true) -> SequenceBand {
        SequenceBand(start: Double(first) - 0.5, end: Double(last) + 0.5, label: label, isShaded: isShaded)
    }
}
