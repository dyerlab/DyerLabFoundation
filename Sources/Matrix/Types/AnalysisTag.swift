//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//                     Making Software That Doesn't Suck
//
//  AnalysisTag.swift
//  DyerLabFoundation
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Created by Rodney Dyer on 7/14/26.
//
//  An open, extensible label for what produced a `NullDistributionResult`
//  (distance-based variance decomposition, rarefaction, a future Mantel
//  test, ...). Deliberately a struct wrapping a raw string, not an enum:
//  Swift enums are closed across modules, so a fixed set of cases here
//  would force every consuming package to route new analyses through
//  Matrix. This ships the tagging *mechanism* only — no predefined values —
//  the same way `Notification.Name` lets any module mint its own constants
//  via `static let` extensions rather than requiring a shared closed set.
//
//  Deliberately not defaulted anywhere it's used as a parameter: the same
//  underlying computation is sometimes given different names by different
//  fields (e.g. AMOVA's Φ_ST and Weir & Cockerham's Θ are the same
//  among/total variance ratio under two subfields' labels), so even a
//  "neutral-sounding" default here would be taking sides in a naming
//  question the foundation has no business arbitrating.
//

/// An open, string-backed label identifying which analysis produced a
/// `NullDistributionResult`. Any module can mint its own values via a
/// `static let`/`static func` extension.
public struct AnalysisTag: Sendable, Equatable, Hashable, CustomStringConvertible {

    /// The tag's underlying label.
    public let rawValue: String

    /// Creates a tag with the given label.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}
