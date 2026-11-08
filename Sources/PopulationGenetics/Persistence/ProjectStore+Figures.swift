//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectStore+Figures.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen

extension ProjectStore {

    /// Writes a figure, replacing any with the same id and keeping its place in the list.
    ///
    /// - Parameter figure: The figure to store.
    /// - Throws: ``PersistenceError/readOnly`` for a read-only store, ``PersistenceError/componentNotPresent(_:)``
    ///   without a `.figures` component, ``PersistenceError/invalidFigure(_:)`` for columns that can't form a table,
    ///   ``PersistenceError/notOpen``, or ``PersistenceError/sqliteError(code:message:)``.
    public func writeFigure(_ figure: StoredFigure) async throws {
        guard mode == .readWrite else { throw PersistenceError.readOnly }
        try requireComponent(.figures, "figures")
        guard Set(figure.columns.map(\.values.count)).count <= 1 else {
            throw PersistenceError.invalidFigure("the columns of \"\(figure.title)\" have different lengths")
        }
        let connection = try requireConnection()
        try connection.beginTransaction()
        do {
            try connection.execute(FiguresSchemaComponent.recordsStatement)
            try upsertRow(for: figure, connection: connection)
            try deleteChildren(of: figure.id, connection: connection)
            try insertColumns(of: figure, connection: connection)
            try insertImages(of: figure, connection: connection)
            try insertRecord(of: figure, connection: connection)
            try setMetaFlag(FiguresSchemaComponent.hasFlagKey, to: true, connection: connection)
            try connection.commit()
        } catch {
            try? connection.rollback()
            throw error
        }
    }

    /// Every stored figure, in list order.
    ///
    /// - Returns: The figures.
    /// - Throws: ``PersistenceError/componentNotPresent(_:)`` without a `.figures` component,
    ///   ``PersistenceError/notOpen``, ``PersistenceError/corruptData(_:)`` for an unreadable row, or
    ///   ``PersistenceError/sqliteError(code:message:)``.
    public func figures() async throws -> [StoredFigure] {
        try requireComponent(.figures, "figures")
        let connection = try requireConnection()
        let stmt = try connection.prepare("\(Self.figureSelection) ORDER BY ordinal")
        let hasRecords = try FiguresSchemaComponent.hasRecords(in: connection)
        var out: [StoredFigure] = []
        while try stmt.step() {
            out.append(try makeFigure(stmt: stmt, hasRecords: hasRecords, connection: connection))
        }
        return out
    }

    /// A single figure by id.
    ///
    /// - Parameter id: The figure's identifier.
    /// - Returns: The figure, or `nil` if none exists.
    /// - Throws: The same errors as ``figures()``.
    public func figure(id: UUID) async throws -> StoredFigure? {
        try requireComponent(.figures, "figures")
        let connection = try requireConnection()
        let stmt = try connection.prepare("\(Self.figureSelection) WHERE upper(uuid) = ?")
        stmt.bind(id.uuidString, at: 1)
        guard try stmt.step() else { return nil }
        return try makeFigure(stmt: stmt, hasRecords: try FiguresSchemaComponent.hasRecords(in: connection),
                              connection: connection)
    }

    /// Removes a figure and everything stored with it.
    ///
    /// - Parameter id: The figure's identifier; removing one that doesn't exist does nothing.
    /// - Throws: ``PersistenceError/readOnly`` for a read-only store, ``PersistenceError/componentNotPresent(_:)``
    ///   without a `.figures` component, ``PersistenceError/notOpen``, or
    ///   ``PersistenceError/sqliteError(code:message:)``.
    public func removeFigure(id: UUID) async throws {
        guard mode == .readWrite else { throw PersistenceError.readOnly }
        try requireComponent(.figures, "figures")
        let connection = try requireConnection()
        try connection.beginTransaction()
        do {
            try connection.execute(FiguresSchemaComponent.recordsStatement)
            try deleteChildren(of: id, connection: connection)
            let stmt = try connection.prepare("DELETE FROM figures WHERE upper(uuid) = ?")
            stmt.bind(id.uuidString, at: 1)
            _ = try stmt.step()
            let remaining = try connection.prepare("SELECT EXISTS (SELECT 1 FROM figures)")
            _ = try remaining.step()
            try setMetaFlag(FiguresSchemaComponent.hasFlagKey, to: remaining.columnInt(at: 0) == 1,
                            connection: connection)
            try connection.commit()
        } catch {
            try? connection.rollback()
            throw error
        }
    }

    // MARK: - Writing

    private func upsertRow(for figure: StoredFigure, connection: SQLiteConnection) throws {
        let ordinal = try connection.prepare("""
            SELECT COALESCE((SELECT ordinal FROM figures WHERE upper(uuid) = ?),
                            (SELECT COALESCE(MAX(ordinal), -1) + 1 FROM figures))
            """)
        ordinal.bind(figure.id.uuidString, at: 1)
        _ = try ordinal.step()
        let stmt = try connection.prepare("""
            INSERT OR REPLACE INTO figures (ordinal, uuid, title, legend, source, form, bins, x_label, y_label,
                                            generator, spec, r_code, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """)
        stmt.bind(ordinal.columnInt(at: 0), at: 1)
        stmt.bind(figure.id.uuidString, at: 2)
        stmt.bind(figure.title, at: 3)
        stmt.bind(figure.legend, at: 4)
        stmt.bind(figure.source, at: 5)
        stmt.bindOptional(figure.formName, at: 6)
        stmt.bindOptional(figure.bins, at: 7)
        stmt.bindOptional(figure.xLabel, at: 8)
        stmt.bindOptional(figure.yLabel, at: 9)
        stmt.bindOptional(figure.generator?.rawValue, at: 10)
        stmt.bindOptional(figure.spec, at: 11)
        stmt.bindOptional(figure.rCode, at: 12)
        stmt.bind(ISO8601DateFormatter().string(from: figure.createdAt), at: 13)
        _ = try stmt.step()
    }

    private func deleteChildren(of id: UUID, connection: SQLiteConnection) throws {
        for table in ["figure_columns", "figure_images", "figure_records"] {
            let stmt = try connection.prepare("DELETE FROM \(table) WHERE upper(figure_uuid) = ?")
            stmt.bind(id.uuidString, at: 1)
            _ = try stmt.step()
        }
    }

    private func insertColumns(of figure: StoredFigure, connection: SQLiteConnection) throws {
        let stmt = try connection.prepare("""
            INSERT INTO figure_columns (figure_uuid, position, name, kind, role, data) VALUES (?, ?, ?, ?, ?, ?)
            """)
        for (position, column) in figure.columns.enumerated() {
            stmt.reset()
            stmt.bind(figure.id.uuidString, at: 1)
            stmt.bind(position, at: 2)
            stmt.bind(column.name, at: 3)
            stmt.bind(FiguresSchemaComponent.kindName(of: column.values), at: 4)
            stmt.bindOptional(column.role?.rawValue, at: 5)
            do {
                stmt.bind(try FiguresSchemaComponent.encode(column.values), at: 6)
            } catch {
                throw PersistenceError.invalidFigure("the values of \"\(column.name)\" can't be encoded")
            }
            _ = try stmt.step()
        }
    }

    private func insertImages(of figure: StoredFigure, connection: SQLiteConnection) throws {
        let stmt = try connection.prepare("""
            INSERT INTO figure_images (figure_uuid, name, mime_type, width, height, data) VALUES (?, ?, ?, ?, ?, ?)
            """)
        for image in figure.images {
            stmt.reset()
            stmt.bind(figure.id.uuidString, at: 1)
            stmt.bind(image.name, at: 2)
            stmt.bind(image.mimeType, at: 3)
            stmt.bindOptional(image.width, at: 4)
            stmt.bindOptional(image.height, at: 5)
            stmt.bind([UInt8](image.data), at: 6)
            _ = try stmt.step()
        }
    }

    private func insertRecord(of figure: StoredFigure, connection: SQLiteConnection) throws {
        guard let record = figure.record else { return }
        let stmt = try connection.prepare("""
            INSERT INTO figure_records (figure_uuid, methods, results, notes, analyst_notes, data_version,
                                        data_modified_at, app_version)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """)
        stmt.bind(figure.id.uuidString, at: 1)
        stmt.bind(record.methods, at: 2)
        stmt.bind(record.results, at: 3)
        stmt.bind(String(decoding: try JSONEncoder().encode(record.notes), as: UTF8.self), at: 4)
        stmt.bind(record.analystNotes, at: 5)
        stmt.bindOptional(record.dataVersion, at: 6)
        stmt.bindOptional(record.dataModifiedAt.map { ISO8601DateFormatter().string(from: $0) }, at: 7)
        stmt.bindOptional(record.appVersion, at: 8)
        _ = try stmt.step()
    }

    // MARK: - Reading

    private static let figureSelection = """
        SELECT uuid, title, legend, source, form, bins, x_label, y_label, generator, spec, r_code, created_at
        FROM figures
        """

    private func makeFigure(stmt: Statement, hasRecords: Bool, connection: SQLiteConnection) throws -> StoredFigure {
        // R writes lowercase ids and Swift uppercase, so children are found in the file's own spelling.
        let storedID = stmt.columnText(at: 0)
        guard let id = UUID(uuidString: storedID) else {
            throw PersistenceError.corruptData("invalid figure uuid: \(storedID)")
        }
        let createdAtText = stmt.columnText(at: 11)
        guard let createdAt = Self.parseFigureDate(createdAtText) else {
            throw PersistenceError.corruptData("invalid figure created_at: \(createdAtText)")
        }
        let title = stmt.columnText(at: 1)
        let columns = try readColumns(figure: storedID, connection: connection)
        guard Set(columns.map(\.values.count)).count <= 1 else {
            throw PersistenceError.corruptData("the columns of figure \"\(title)\" have different lengths")
        }
        return StoredFigure(id: id,
                            title: title,
                            legend: stmt.columnText(at: 2),
                            source: stmt.columnText(at: 3),
                            formName: stmt.columnIsNull(at: 4) ? nil : stmt.columnText(at: 4),
                            bins: stmt.columnOptionalInt(at: 5),
                            xLabel: stmt.columnIsNull(at: 6) ? nil : stmt.columnText(at: 6),
                            yLabel: stmt.columnIsNull(at: 7) ? nil : stmt.columnText(at: 7),
                            generator: stmt.columnIsNull(at: 8)
                                ? nil : FigureGenerator(rawValue: stmt.columnText(at: 8)),
                            spec: stmt.columnIsNull(at: 9) ? nil : stmt.columnText(at: 9),
                            rCode: stmt.columnIsNull(at: 10) ? nil : stmt.columnText(at: 10),
                            createdAt: createdAt,
                            columns: columns,
                            images: try readImages(figure: storedID, connection: connection),
                            record: hasRecords ? try readRecord(figure: storedID, connection: connection) : nil)
    }

    private func readRecord(figure: String, connection: SQLiteConnection) throws -> ResultRecord? {
        let stmt = try connection.prepare("""
            SELECT methods, results, notes, analyst_notes, data_version, data_modified_at, app_version
            FROM figure_records WHERE figure_uuid = ?
            """)
        stmt.bind(figure, at: 1)
        guard try stmt.step() else { return nil }
        guard let notes = try? JSONDecoder().decode([String].self, from: Data(stmt.columnText(at: 2).utf8)) else {
            throw PersistenceError.corruptData("unreadable notes in the record of figure \(figure)")
        }
        return ResultRecord(methods: stmt.columnText(at: 0),
                            results: stmt.columnText(at: 1),
                            notes: notes,
                            analystNotes: stmt.columnText(at: 3),
                            dataVersion: stmt.columnIsNull(at: 4) ? nil : stmt.columnText(at: 4),
                            dataModifiedAt: stmt.columnIsNull(at: 5)
                                ? nil : Self.parseFigureDate(stmt.columnText(at: 5)),
                            appVersion: stmt.columnIsNull(at: 6) ? nil : stmt.columnText(at: 6))
    }

    private func readColumns(figure: String, connection: SQLiteConnection) throws -> [FigureColumn] {
        let stmt = try connection.prepare("""
            SELECT name, kind, role, data FROM figure_columns WHERE figure_uuid = ? ORDER BY position
            """)
        stmt.bind(figure, at: 1)
        var columns: [FigureColumn] = []
        while try stmt.step() {
            let role = stmt.columnIsNull(at: 2) ? nil : DataColumnRole(rawValue: stmt.columnText(at: 2))
            columns.append(FigureColumn(name: stmt.columnText(at: 0),
                                        role: role,
                                        values: try FiguresSchemaComponent.decode(stmt.columnText(at: 3),
                                                                                  kind: stmt.columnText(at: 1))))
        }
        return columns
    }

    private func readImages(figure: String, connection: SQLiteConnection) throws -> [ResultImage] {
        let stmt = try connection.prepare("""
            SELECT name, mime_type, width, height, data FROM figure_images WHERE figure_uuid = ? ORDER BY name
            """)
        stmt.bind(figure, at: 1)
        var images: [ResultImage] = []
        while try stmt.step() {
            images.append(ResultImage(name: stmt.columnText(at: 0),
                                      mimeType: stmt.columnText(at: 1),
                                      width: stmt.columnOptionalInt(at: 2),
                                      height: stmt.columnOptionalInt(at: 3),
                                      data: Data(stmt.columnBlob(at: 4))))
        }
        return images
    }

    /// Reads a stored date, with or without fractional seconds, since R's formatting allows either.
    ///
    /// - Parameter text: The ISO 8601 text.
    /// - Returns: The date, or `nil` if the text isn't one.
    private static func parseFigureDate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: text)
    }
}
