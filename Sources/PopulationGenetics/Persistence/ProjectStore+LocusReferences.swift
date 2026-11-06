//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectStore+LocusReferences.swift
//  PopulationGenetics
//
//  The names of the loci a graph was built from (usually SNP reference names),
//  kept in `project_metadata` so a file needs no `loci` table to record them.
//  `graph_loci` can't do that: it stores ordinals into `.geneticData`'s table.
//
//  Created by Rodney Dyer on 2026.11.05.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

extension ProjectStore {

    /// The names of the loci the file's graph was built from.
    ///
    /// A file's explicit list wins. Without one, a file holding genetic data
    /// falls back to the names of the loci in `graph_loci`.
    ///
    /// - Returns: The references in stored order; empty if none are recorded.
    /// - Throws: ``PersistenceError/notOpen``, ``PersistenceError/corruptData(_:)`` if the stored
    ///   list isn't a JSON array of strings, or ``PersistenceError/sqliteError(code:message:)``.
    public func graphLocusReferences() async throws -> [String] {
        if let stored = try await metadata(forKey: MetadataKey.graphLocusReferences) {
            guard let references = try? JSONDecoder().decode([String].self, from: Data(stored.utf8)) else {
                throw PersistenceError.corruptData("the graph's locus references aren't a list of names")
            }
            return references
        }
        guard presentComponents.contains(.graph), presentComponents.contains(.geneticData) else { return [] }
        return try await readGraph().loci.map(\.name)
    }

    /// Records the names of the loci the file's graph was built from. Whatever
    /// replaces a file's graph must call this too, because `writeGraph` doesn't.
    ///
    /// - Parameter references: The names, in order. An empty list removes the record.
    /// - Throws: ``PersistenceError/readOnly`` for a read-only store, ``PersistenceError/notOpen``,
    ///   or ``PersistenceError/sqliteError(code:message:)`` if the write fails.
    public func setGraphLocusReferences(_ references: [String]) async throws {
        let encoded = references.isEmpty ? nil : String(decoding: try JSONEncoder().encode(references), as: UTF8.self)
        try await setMetadata(encoded, forKey: MetadataKey.graphLocusReferences)
    }
}
