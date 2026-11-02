//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AnalysisOperand.swift
//  Matrix
//
//  Created by Rodney Dyer on 2026.11.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

/// One input an analysis takes, described by its role and kind.
public struct AnalysisOperand: Sendable, Equatable, Hashable {

    /// The operand's role, e.g. `"response"` or `"groups"`.
    public let role: String

    /// What kind of value the operand holds.
    public let kind: AnalysisOperandKind

    /// Creates an operand description.
    ///
    /// - Parameters:
    ///   - role: The operand's role.
    ///   - kind: What kind of value it holds.
    public init(role: String, kind: AnalysisOperandKind) {
        self.role = role
        self.kind = kind
    }
}
