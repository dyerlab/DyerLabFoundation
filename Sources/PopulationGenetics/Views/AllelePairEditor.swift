//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AllelePairEditor.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// Two text fields around a fixed separator, editing one diploid genotype on any platform.
///
/// This is for lists and forms. For a cell in an AppKit table, use `AllelePairCellView`.
public struct AllelePairEditor: View {

    /// The two fields.
    private enum Field {
        /// The left allele's field.
        case left
        /// The right allele's field.
        case right
    }

    /// The text between the alleles.
    public let separator: String
    /// Called with the joined genotype when the user presses Return.
    public let onCommit: (String) -> Void
    /// Called when the user presses Esc.
    public let onCancel: () -> Void

    @State private var pair: AllelePairText
    @FocusState private var focus: Field?

    /// Creates an editor.
    ///
    /// - Parameters:
    ///   - value: The joined genotype, such as `01:02`, or `""` for none.
    ///   - separator: The text between the alleles.
    ///   - onCommit: Called with the joined genotype when the user presses Return.
    ///   - onCancel: Called when the user presses Esc.
    public init(value: String,
                separator: String = ":",
                onCommit: @escaping (String) -> Void,
                onCancel: @escaping () -> Void = {}) {
        self.separator = separator
        self.onCommit = onCommit
        self.onCancel = onCancel
        _pair = State(initialValue: AllelePairText(value: value, separator: separator))
    }

    /// The fields and separator.
    public var body: some View {
        HStack(spacing: 2) {
            TextField("Left allele", text: $pair.left)
                .focused($focus, equals: .left)
            Text(separator)
            TextField("Right allele", text: $pair.right)
                .focused($focus, equals: .right)
        }
        .labelsHidden()
        .multilineTextAlignment(.center)
        .onSubmit { onCommit(pair.value(separator: separator)) }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
        .onAppear { focus = .left }
    }
}

// MARK: - Previews

#Preview {
    AllelePairEditor(value: "01:02") { _ in }
        .padding()
        .frame(width: 160)
}
