//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectStore+Metadata.swift
//  PopulationGenetics
//
//  Read/write access to a file's project metadata: the reserved identity keys
//  in `ProjectStore.MetadataKey` plus any string key/value pairs an app wants
//  to keep with the file. See `ProjectMetadataSchema.swift` for storage.
//
//  Created by Rodney Dyer on 2026.10.24.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension ProjectStore {

    /// The project-metadata keys this package reads and writes itself. Any
    /// other key is the app's to define.
    public enum MetadataKey {
        /// The project's name. Always present; it can be changed but not removed.
        public static let projectName = "project_name"
        /// The species this project concerns.
        public static let species = "species"
        /// Free-text description of what this project is focused on.
        public static let description = "description"
    }

    /// Every project-metadata pair in the file, reserved keys included.
    ///
    /// - Returns: The stored key/value pairs.
    /// - Throws: ``PersistenceError/notOpen`` or ``PersistenceError/sqliteError(code:message:)``.
    public func metadata() async throws -> [String: String] {
        try ProjectMetadataSchema.read(try requireConnection())
    }

    /// The value stored for one project-metadata key.
    ///
    /// - Parameter key: The key to look up, e.g. ``MetadataKey/species`` or an app-defined key.
    /// - Returns: The value, or `nil` if the key isn't set.
    /// - Throws: ``PersistenceError/notOpen`` or ``PersistenceError/sqliteError(code:message:)``.
    public func metadata(forKey key: String) async throws -> String? {
        try await metadata()[key]
    }

    /// Sets or removes one project-metadata value.
    ///
    /// - Parameters:
    ///   - value: The new value. `nil` or an empty string removes the key.
    ///   - key: The key to change.
    /// - Throws: ``PersistenceError/readOnly`` for a read-only store, ``PersistenceError/notOpen``,
    ///   ``PersistenceError/invalidMetadata(_:)`` when removing ``MetadataKey/projectName``, or
    ///   ``PersistenceError/sqliteError(code:message:)`` if the write fails.
    public func setMetadata(_ value: String?, forKey key: String) async throws {
        try await updateMetadata([key: value])
    }

    /// Applies several project-metadata changes in one transaction. Keys not
    /// named in `changes` are left as they are.
    ///
    /// - Parameter changes: The new value per key. A `nil` or empty value removes that key.
    /// - Throws: ``PersistenceError/readOnly`` for a read-only store, ``PersistenceError/notOpen``,
    ///   ``PersistenceError/invalidMetadata(_:)`` when removing ``MetadataKey/projectName``, or
    ///   ``PersistenceError/sqliteError(code:message:)`` if a write fails. Nothing is changed when it throws.
    public func updateMetadata(_ changes: [String: String?]) async throws {
        guard mode == .readWrite else { throw PersistenceError.readOnly }
        let connection = try requireConnection()
        var stored: [String: String] = [:]
        var removed: [String] = []
        for (key, value) in changes {
            if let value, !value.isEmpty {
                stored[key] = value
            } else {
                removed.append(key)
            }
        }
        if removed.contains(MetadataKey.projectName) {
            throw PersistenceError.invalidMetadata("\(MetadataKey.projectName) can't be removed")
        }
        try connection.beginTransaction()
        do {
            try ProjectMetadataSchema.write(stored, connection: connection)
            try ProjectMetadataSchema.remove(removed, connection: connection)
            try connection.commit()
        } catch {
            try? connection.rollback()
            throw error
        }
    }

    /// Builds the metadata a new file starts with: `metadata`, overridden by
    /// whichever identity arguments are given. Empty values are dropped.
    ///
    /// - Parameters:
    ///   - metadata: App-defined pairs (and, optionally, reserved keys).
    ///   - projectName: The project's name.
    ///   - species: The species, if any.
    ///   - description: A description, if any.
    /// - Returns: The pairs to write.
    static func initialMetadata(_ metadata: [String: String], projectName: String, species: String?,
                                description: String?) -> [String: String] {
        var values = metadata.filter { !$0.value.isEmpty }
        values[MetadataKey.projectName] = projectName
        if let species, !species.isEmpty { values[MetadataKey.species] = species }
        if let description, !description.isEmpty { values[MetadataKey.description] = description }
        return values
    }
}
