//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  AllelePairCellViewTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

#if os(macOS)
import AppKit
import Testing
@testable import PopulationGenetics

@MainActor
struct AllelePairCellViewTests {

    /// The cell's two text fields, left then right.
    private func fields(of cell: AllelePairCellView) throws -> (left: NSTextField, right: NSTextField) {
        let stack = try #require(cell.subviews.compactMap { $0 as? NSStackView }.first)
        let editable = stack.views.compactMap { $0 as? NSTextField }.filter(\.isEditable)
        #expect(editable.count == 2)
        return (try #require(editable.first), try #require(editable.last))
    }

    private func press(_ command: Selector, in field: NSTextField, of cell: AllelePairCellView) -> Bool {
        cell.control(field, textView: NSTextView(), doCommandBy: command)
    }

    private func editingCell(value: String, onCommit: @escaping (String) -> Bool) -> AllelePairCellView {
        let cell = AllelePairCellView(frame: NSRect(x: 0, y: 0, width: 72, height: 22))
        cell.configure(value: value, separator: ":", alignment: .center)
        cell.onCommit = onCommit
        cell.beginEditing()
        return cell
    }

    @Test func editingSplitsTheGenotypeIntoItsFields() throws {
        let cell = editingCell(value: "01:02") { _ in true }
        #expect(cell.isEditing)
        let (left, right) = try fields(of: cell)
        #expect(left.stringValue == "01")
        #expect(right.stringValue == "02")
    }

    @Test func returnCommitsTheJoinedGenotype() throws {
        var committed: [String] = []
        let cell = editingCell(value: "01:02") {
            committed.append($0)
            return true
        }
        let (left, right) = try fields(of: cell)
        left.stringValue = " 03 "
        right.stringValue = "04"
        #expect(press(#selector(NSResponder.insertNewline(_:)), in: left, of: cell))
        #expect(!cell.isEditing)
        #expect(committed == ["03:04"])
    }

    @Test func clearingBothFieldsCommitsMissingData() throws {
        var committed: [String] = []
        let cell = editingCell(value: "01:02") {
            committed.append($0)
            return true
        }
        let (left, right) = try fields(of: cell)
        left.stringValue = ""
        right.stringValue = ""
        #expect(press(#selector(NSResponder.insertNewline(_:)), in: left, of: cell))
        #expect(committed == [""])
    }

    @Test func escapeLeavesTheValueAlone() throws {
        var committed: [String] = []
        let cell = editingCell(value: "01:02") {
            committed.append($0)
            return true
        }
        let (left, _) = try fields(of: cell)
        left.stringValue = "09"
        #expect(press(#selector(NSResponder.cancelOperation(_:)), in: left, of: cell))
        #expect(!cell.isEditing)
        #expect(committed.isEmpty)
    }

    @Test func tabCommitsOnlyWhenLeavingThePair() throws {
        var committed: [String] = []
        let cell = editingCell(value: "01:02") {
            committed.append($0)
            return true
        }
        let (left, right) = try fields(of: cell)
        #expect(!press(#selector(NSResponder.insertTab(_:)), in: left, of: cell))
        #expect(cell.isEditing)
        right.stringValue = "05"
        #expect(press(#selector(NSResponder.insertTab(_:)), in: right, of: cell))
        #expect(committed == ["01:05"])
    }

    @Test func anUnchangedValueIsNotCommitted() throws {
        var committed: [String] = []
        let cell = editingCell(value: "01:02") {
            committed.append($0)
            return true
        }
        let (left, _) = try fields(of: cell)
        #expect(press(#selector(NSResponder.insertNewline(_:)), in: left, of: cell))
        #expect(committed.isEmpty)
    }
}
#endif
