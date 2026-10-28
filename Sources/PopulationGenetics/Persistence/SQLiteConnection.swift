//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  SQLiteConnection.swift
//  PopulationGenetics
//
//  A thin wrapper around the raw SQLite3 C API. Isolates every `sqlite3_*`
//  call so the schema-encoding/decoding code above it stays readable. Not
//  thread-safe on its own; callers (e.g. `ProjectStore`, an actor)
//  are responsible for serializing access.
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import SQLite3

/// A single open connection to a SQLite database file.
final class SQLiteConnection {

    enum OpenMode: Sendable {
        case readOnly
        case readWrite
        case readWriteCreate
    }

    private var db: OpaquePointer?

    var isOpen: Bool { db != nil }

    func open(at url: URL, mode: OpenMode) throws {
        let flags: Int32
        switch mode {
        case .readOnly: flags = SQLITE_OPEN_READONLY
        case .readWrite: flags = SQLITE_OPEN_READWRITE
        case .readWriteCreate: flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        }
        var handle: OpaquePointer?
        let result = sqlite3_open_v2(url.path, &handle, flags, nil)
        guard result == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unable to open database at \(url.path)"
            if let handle { sqlite3_close(handle) }
            throw PersistenceError.cannotOpen(message)
        }
        self.db = handle
    }

    func close() {
        guard let db else { return }
        sqlite3_close(db)
        self.db = nil
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    func execute(_ sql: String) throws {
        guard let db else { throw PersistenceError.notOpen }
        var errMsg: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(db, sql, nil, nil, &errMsg)
        guard result == SQLITE_OK else {
            let message = errMsg.map { String(cString: $0) } ?? "unknown SQLite error"
            sqlite3_free(errMsg)
            throw PersistenceError.sqliteError(code: result, message: message)
        }
    }

    func prepare(_ sql: String) throws -> Statement {
        guard let db else { throw PersistenceError.notOpen }
        var handle: OpaquePointer?
        let result = sqlite3_prepare_v2(db, sql, -1, &handle, nil)
        guard result == SQLITE_OK, let handle else {
            let message = String(cString: sqlite3_errmsg(db))
            throw PersistenceError.sqliteError(code: result, message: message)
        }
        return Statement(handle: handle, db: db)
    }

    func beginTransaction() throws { try execute("BEGIN IMMEDIATE") }
    func commit() throws { try execute("COMMIT") }
    func rollback() throws { try execute("ROLLBACK") }

    func setUserVersion(_ version: Int32) throws {
        try execute("PRAGMA user_version = \(version)")
    }

    func userVersion() throws -> Int32 {
        let stmt = try prepare("PRAGMA user_version")
        _ = try stmt.step()
        return stmt.columnInt32(at: 0)
    }

    /// Checkpoints the WAL back into the main file and truncates it, so the
    /// file left on disk after `close()` has no `-wal`/`-shm` sidecars.
    ///
    /// - Throws: ``PersistenceError/notOpen`` or ``PersistenceError/sqliteError(code:message:)``.
    func checkpointAndTruncateWAL() throws {
        try execute("PRAGMA wal_checkpoint(TRUNCATE)")
    }
}
