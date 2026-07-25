//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMatrixStore+Log.swift
//  PopulationGenetics
//
//  Read/write access to the `log_entries` table — a generic, append-only
//  running log of timestamped notes (file I/O, warnings, errors, documented
//  assumptions, ...) recorded alongside a project's data. Mirrors
//  `GenotypeMatrixStore+Results.swift`'s shape (ordinal PK for insertion
//  order, uuid for stable identity).
//

import Foundation
import PresentationZen
import Matrix

extension GenotypeMatrixStore {

    /// Appends one log entry. Entries are never updated in place; each call adds a new row.
    public func appendLog(_ entry: LogEntry) async throws {
        guard mode == .readWrite else { throw PersistenceError.readOnly }
        let connection = try requireConnection()
        let ordinal = try nextLogOrdinal(connection: connection)
        let stmt = try connection.prepare("""
            INSERT INTO log_entries (ordinal, uuid, timestamp, log_type, analysis_tag, message)
            VALUES (?, ?, ?, ?, ?, ?)
            """)
        stmt.bind(ordinal, at: 1)
        stmt.bind(entry.id.uuidString, at: 2)
        stmt.bind(ISO8601DateFormatter().string(from: entry.timestamp), at: 3)
        stmt.bind(entry.logType.rawValue, at: 4)
        stmt.bindOptional(entry.analysisTag?.rawValue, at: 5)
        stmt.bind(entry.message, at: 6)
        _ = try stmt.step()
        try setMetaFlag("has_log", to: true, connection: connection)
    }

    /// All log entries, in the order they were added.
    public func logEntries() async throws -> [LogEntry] {
        let connection = try requireConnection()
        let stmt = try connection.prepare("""
            SELECT uuid, timestamp, log_type, analysis_tag, message FROM log_entries ORDER BY ordinal
            """)
        let formatter = ISO8601DateFormatter()
        var out: [LogEntry] = []
        while try stmt.step() {
            out.append(try makeLogEntry(stmt: stmt, formatter: formatter))
        }
        return out
    }

    private func nextLogOrdinal(connection: SQLiteConnection) throws -> Int {
        let stmt = try connection.prepare("SELECT COALESCE(MAX(ordinal), -1) + 1 FROM log_entries")
        _ = try stmt.step()
        return stmt.columnInt(at: 0)
    }

    private func makeLogEntry(stmt: Statement, formatter: ISO8601DateFormatter) throws -> LogEntry {
        let uuidString = stmt.columnText(at: 0)
        guard let uuid = UUID(uuidString: uuidString) else {
            throw PersistenceError.corruptData("invalid log entry uuid: \(uuidString)")
        }
        let timestampString = stmt.columnText(at: 1)
        guard let timestamp = formatter.date(from: timestampString) else {
            throw PersistenceError.corruptData("invalid log entry timestamp: \(timestampString)")
        }
        let analysisTag = stmt.columnIsNull(at: 3) ? nil : AnalysisTag(stmt.columnText(at: 3))
        return LogEntry(id: uuid, timestamp: timestamp, logType: LogType(stmt.columnText(at: 2)),
                         analysisTag: analysisTag, message: stmt.columnText(at: 4))
    }
}
