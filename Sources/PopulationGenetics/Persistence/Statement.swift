//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Statement.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import SQLite3

/// SQLite's `SQLITE_TRANSIENT`: tells `sqlite3_bind_text`/`_blob` to copy the bytes immediately.
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// A prepared SQLite statement. Bind parameters are 1-based, matching the
/// SQLite C API convention.
final class Statement {

    fileprivate let handle: OpaquePointer
    private let db: OpaquePointer

    init(handle: OpaquePointer, db: OpaquePointer) {
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

    // MARK: - Binding

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

    // MARK: - Stepping

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

    // MARK: - Column access (0-based, matching the SQLite C API convention)

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
