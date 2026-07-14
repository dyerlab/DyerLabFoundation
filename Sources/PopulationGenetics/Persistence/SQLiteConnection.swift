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
//  thread-safe on its own; callers (e.g. `GenotypeMatrixStore`, an actor)
//  are responsible for serializing access.
//

import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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
    func checkpointAndTruncateWAL() throws {
        try execute("PRAGMA wal_checkpoint(TRUNCATE)")
    }
}

/// A prepared SQLite statement. Bind parameters are 1-based, matching the
/// SQLite C API convention.
final class Statement {

    fileprivate let handle: OpaquePointer
    private let db: OpaquePointer

    fileprivate init(handle: OpaquePointer, db: OpaquePointer) {
        self.handle = handle
        self.db = db
    }

    deinit {
        sqlite3_finalize(handle)
    }

    func reset() {
        sqlite3_reset(handle)
        sqlite3_clear_bindings(handle)
    }

    // MARK: Binding

    func bind(_ value: Int, at index: Int32) {
        sqlite3_bind_int64(handle, index, Int64(value))
    }

    func bind(_ value: Double, at index: Int32) {
        sqlite3_bind_double(handle, index, value)
    }

    func bind(_ value: String, at index: Int32) {
        sqlite3_bind_text(handle, index, value, -1, sqliteTransient)
    }

    func bind(_ value: [UInt8], at index: Int32) {
        value.withUnsafeBytes { buf in
            _ = sqlite3_bind_blob(handle, index, buf.baseAddress, Int32(buf.count), sqliteTransient)
        }
    }

    func bindNull(at index: Int32) {
        sqlite3_bind_null(handle, index)
    }

    func bindOptional(_ value: Int?, at index: Int32) {
        if let value { bind(value, at: index) } else { bindNull(at: index) }
    }

    func bindOptional(_ value: Double?, at index: Int32) {
        if let value { bind(value, at: index) } else { bindNull(at: index) }
    }

    func bindOptional(_ value: String?, at index: Int32) {
        if let value { bind(value, at: index) } else { bindNull(at: index) }
    }

    func bindOptional(_ value: [UInt8]?, at index: Int32) {
        if let value { bind(value, at: index) } else { bindNull(at: index) }
    }

    // MARK: Stepping

    @discardableResult
    func step() throws -> Bool {
        let result = sqlite3_step(handle)
        switch result {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default:
            let message = String(cString: sqlite3_errmsg(db))
            throw PersistenceError.sqliteError(code: result, message: message)
        }
    }

    // MARK: Column access (0-based, matching the SQLite C API convention)

    func columnIsNull(at index: Int32) -> Bool {
        sqlite3_column_type(handle, index) == SQLITE_NULL
    }

    func columnInt(at index: Int32) -> Int {
        Int(sqlite3_column_int64(handle, index))
    }

    func columnInt32(at index: Int32) -> Int32 {
        sqlite3_column_int(handle, index)
    }

    func columnDouble(at index: Int32) -> Double {
        sqlite3_column_double(handle, index)
    }

    func columnText(at index: Int32) -> String {
        guard let cString = sqlite3_column_text(handle, index) else { return "" }
        return String(cString: cString)
    }

    func columnBlob(at index: Int32) -> [UInt8] {
        let count = Int(sqlite3_column_bytes(handle, index))
        guard count > 0, let bytes = sqlite3_column_blob(handle, index) else { return [] }
        let buffer = bytes.assumingMemoryBound(to: UInt8.self)
        return [UInt8](UnsafeBufferPointer(start: buffer, count: count))
    }

    func columnOptionalInt(at index: Int32) -> Int? {
        columnIsNull(at: index) ? nil : columnInt(at: index)
    }

    func columnOptionalDouble(at index: Int32) -> Double? {
        columnIsNull(at: index) ? nil : columnDouble(at: index)
    }
}
