//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AllelePairCellView.swift
//  PopulationGenetics
//
//  Shows a value such as `01:02` as one label, and edits it as two fields
//  around a fixed separator so each part is typed separately. Tab moves from
//  the left field to the right; Return, Tab out of the right field, or
//  clicking elsewhere commits; Esc cancels.
//
//  Created by Rodney Dyer on 2026.10.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

#if os(macOS)
import AppKit
import SwiftUI

/// A spreadsheet cell holding a two-part value, edited one part at a time.
public final class AllelePairCellView: NSTableCellView, NSTextFieldDelegate {

    /// The reuse identifier for table cells of this kind.
    public static let identifier = NSUserInterfaceItemIdentifier("AllelePairCell")

    /// Called with the new value when an edit is committed; return `false`
    /// to reject it, which beeps and restores the old value.
    public var onCommit: ((String) -> Bool)?

    /// Called with `true` when editing begins and `false` when it ends.
    public var onEditingChanged: ((Bool) -> Void)?

    private let display = NSTextField(labelWithString: "")
    private let leftField = NSTextField()
    private let rightField = NSTextField()
    private let separatorLabel = NSTextField(labelWithString: ":")
    private let editors = NSStackView()
    private var separator = ":"
    private var value = ""
    /// Whether the two fields are showing instead of the label.
    private(set) var isEditing = false

    // MARK: - Initialization

    /// Creates a cell showing nothing.
    ///
    /// - Parameter frameRect: The cell's initial frame.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier

        display.alignment = .center
        display.lineBreakMode = .byClipping
        display.translatesAutoresizingMaskIntoConstraints = false
        addSubview(display)

        for field in [leftField, rightField] {
            field.delegate = self
            field.controlSize = .small
            field.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            field.alignment = .center
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
        }
        leftField.nextKeyView = rightField
        editors.orientation = .horizontal
        editors.spacing = 1
        editors.distribution = .fill
        editors.setViews([leftField, separatorLabel, rightField], in: .center)
        editors.translatesAutoresizingMaskIntoConstraints = false
        editors.isHidden = true
        addSubview(editors)

        NSLayoutConstraint.activate([
            display.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            display.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            display.centerYAnchor.constraint(equalTo: centerYAnchor),
            editors.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            editors.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            editors.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftField.widthAnchor.constraint(equalTo: rightField.widthAnchor),
        ])
    }

    /// Not supported: cells are created in code.
    ///
    /// - Parameter coder: Unused.
    public required init?(coder: NSCoder) {
        fatalError("AllelePairCellView is created in code only")
    }

    // MARK: - Configuration

    /// Shows a value, ending any edit in progress without committing it.
    ///
    /// - Parameters:
    ///   - value: The joined value, e.g. `01:02`, or `""` for none.
    ///   - separator: The text between the two parts.
    ///   - alignment: How the value is aligned when not editing.
    public func configure(value: String, separator: String, alignment: NSTextAlignment) {
        if isEditing { endEditing(commit: false) }
        self.value = value
        self.separator = separator
        display.stringValue = value
        display.alignment = alignment
        separatorLabel.stringValue = separator
    }

    /// Swaps the label for the two fields and puts the cursor in the left one.
    public func beginEditing() {
        guard !isEditing else { return }
        let pair = AllelePairText(value: value, separator: separator)
        leftField.stringValue = pair.left
        rightField.stringValue = pair.right
        isEditing = true
        display.isHidden = true
        editors.isHidden = false
        onEditingChanged?(true)
        window?.makeFirstResponder(leftField)
    }

    // MARK: - NSTextFieldDelegate

    /// Handles Return, Esc and Tab out of the pair.
    ///
    /// - Parameters:
    ///   - control: The field being edited.
    ///   - textView: The field's editor.
    ///   - commandSelector: The key command.
    /// - Returns: `true` if the command ended the edit.
    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            endEditing(commit: true)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            endEditing(commit: false)
            return true
        case #selector(NSResponder.insertTab(_:)) where control === rightField,
             #selector(NSResponder.insertBacktab(_:)) where control === leftField:
            endEditing(commit: true)
            return true
        default:
            return false
        }
    }

    /// Commits the edit once focus has left both fields.
    ///
    /// - Parameter notification: The end-of-editing notification.
    public func controlTextDidEndEditing(_ notification: Notification) {
        // Focus may only be moving between the two fields; commit once it has
        // left both (e.g. a click elsewhere in the table).
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isEditing, !self.hasFocus else { return }
            self.endEditing(commit: true)
        }
    }

    private var hasFocus: Bool {
        guard let editor = window?.firstResponder as? NSTextView,
              let field = editor.delegate as? NSTextField else { return false }
        return field === leftField || field === rightField
    }

    // MARK: - Ending an edit

    private func endEditing(commit: Bool) {
        guard isEditing else { return }
        isEditing = false
        let edited = AllelePairText(left: leftField.stringValue, right: rightField.stringValue)
            .value(separator: separator)
        editors.isHidden = true
        display.isHidden = false
        if hasFocus { window?.makeFirstResponder(enclosingTableView) }
        onEditingChanged?(false)
        guard commit, edited != value else { return }
        if onCommit?(edited) == true {
            value = edited
            display.stringValue = edited
        } else {
            NSSound.beep()
        }
    }

    private var enclosingTableView: NSTableView? {
        var view = superview
        while let current = view, !(current is NSTableView) { view = current.superview }
        return view as? NSTableView
    }
}

// MARK: - Previews

#Preview {
    let cell = AllelePairCellView(frame: NSRect(x: 0, y: 0, width: 72, height: 22))
    cell.configure(value: "01:02", separator: ":", alignment: .center)
    return cell
}

#endif
