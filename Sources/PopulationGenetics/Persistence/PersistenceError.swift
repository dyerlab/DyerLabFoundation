//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PersistenceError.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Errors thrown by the SQLite-backed `ProjectStore`.
public enum PersistenceError: LocalizedError, Equatable {
    /// The file at the given path could not be opened.
    case cannotOpen(String)
    /// A SQLite call failed with the given result code and message.
    case sqliteError(code: Int32, message: String)
    /// The file's schema version does not match what this library expects.
    case schemaVersionMismatch(found: Int32, expected: Int32)
    /// The stored data could not be reconstructed into valid in-memory types.
    case corruptData(String)
    /// The store has no open connection.
    case notOpen
    /// A write was attempted on a store opened `.readOnly`.
    case readOnly
    /// The requested component (e.g. `.graph`) was never created for this file.
    case componentNotPresent(String)
    /// A project-metadata change was rejected, e.g. removing the project name.
    case invalidMetadata(String)

    /// A user-presentable description of the failure.
    public var errorDescription: String? {
        switch self {
        case .cannotOpen(let path):
            "The project file at \(path) could not be opened."
        case .sqliteError(let code, let message):
            "The project file could not be read or written (SQLite error \(code): \(message))."
        case .schemaVersionMismatch(let found, let expected):
            "The project file uses format version \(found), but this app expects version \(expected)."
        case .corruptData(let detail):
            "The project file is damaged: \(detail)"
        case .notOpen:
            "No project file is open."
        case .readOnly:
            "The project file was opened read-only and can't be changed."
        case .componentNotPresent(let component):
            "The project file has no \(component) data."
        case .invalidMetadata(let detail):
            "The project details couldn't be changed: \(detail)."
        }
    }
}
