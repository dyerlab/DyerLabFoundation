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

/// Errors thrown by the SQLite-backed `GenotypeMatrixStore`.
public enum PersistenceError: Error, Equatable {
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
}
