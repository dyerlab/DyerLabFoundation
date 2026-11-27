//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  SequenceMarker.swift
//  PresentationZenCore
//
//  Something that happened between two positions of a sequence (a change was made), drawn as a dashed rule.
//
//  Created by Rodney Dyer on 2026.11.27.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A dashed vertical rule in a ``SequencePlot``.
public struct SequenceMarker: Hashable, Identifiable, Sendable {
    /// Where the rule is drawn; between positions `n` and `n + 1` is `n + 0.5`.
    public var position: Double
    /// A short label drawn at the rule's top, or `nil` for none.
    public var label: String?

    /// The rule's place on the axis.
    public var id: Double { position }

    /// Creates a marker.
    ///
    /// - Parameters:
    ///   - position: Where the rule is drawn.
    ///   - label: A short label, or `nil`.
    public init(position: Double, label: String? = nil) {
        self.position = position
        self.label = label
    }

    /// The marker between position `position` and the one after it.
    ///
    /// - Parameters:
    ///   - position: The position before the rule.
    ///   - label: A short label, or `nil`.
    /// - Returns: The marker.
    public static func after(_ position: Int, label: String? = nil) -> SequenceMarker {
        SequenceMarker(position: Double(position) + 0.5, label: label)
    }
}
