//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectStore+Matrices.swift
//  PopulationGenetics
//
//  Read/write access to the `.matrices` component's `matrices` table —
//  named, generic `Matrix` attachments (a derived Fst distance matrix, PCA
//  loadings, ...), append-only like `results`/`log_entries`.
//
//  `Matrix` (from the `Matrix` target) is a mutable, non-`Sendable` class, so
//  it never crosses this actor's isolation boundary directly. This API works
//  in `Data` instead — the caller encodes/decodes via `Matrix`'s existing
//  `Codable` conformance (`Matrix+Codable.swift`) outside actor isolation,
//  exactly mirroring how `ResultImage.data` carries raw image bytes rather
//  than a live `UIImage`/`NSImage`:
//
//      try await store.addMatrix(JSONEncoder().encode(myMatrix), name: "Fst distances")
//      ...
//      if let data = try await store.matrixData(named: "Fst distances") {
//          let matrix = try JSONDecoder().decode(Matrix.self, from: data)
//      }
//

import Foundation
import PresentationZen

extension ProjectStore {

    /// Appends one named matrix. Never updated in place; each call adds a new row.
    public func addMatrix(_ data: Data, name: String, description: String? = nil) async throws {
        guard mode == .readWrite else { throw PersistenceError.readOnly }
        try requireComponent(.matrices, "matrices")
        let connection = try requireConnection()
        let ordinal = try nextMatrixOrdinal(connection: connection)
        let stmt = try connection.prepare("""
            INSERT INTO matrices (ordinal, uuid, name, description, created_at, data) VALUES (?, ?, ?, ?, ?, ?)
            """)
        stmt.bind(ordinal, at: 1)
        stmt.bind(UUID().uuidString, at: 2)
        stmt.bind(name, at: 3)
        stmt.bindOptional(description, at: 4)
        stmt.bind(ISO8601DateFormatter().string(from: Date()), at: 5)
        stmt.bind([UInt8](data), at: 6)
        _ = try stmt.step()
        try setMetaFlag(MatricesSchemaComponent.hasFlagKey, to: true, connection: connection)
    }

    /// Metadata for every stored matrix, in the order they were added. Fetch
    /// the payload separately via `matrixData(named:)`.
    public func matrices() async throws -> [StoredMatrixInfo] {
        try requireComponent(.matrices, "matrices")
        let connection = try requireConnection()
        let stmt = try connection.prepare("""
            SELECT uuid, name, description, created_at FROM matrices ORDER BY ordinal
            """)
        let formatter = ISO8601DateFormatter()
        var out: [StoredMatrixInfo] = []
        while try stmt.step() {
            out.append(try makeMatrixInfo(stmt: stmt, formatter: formatter))
        }
        return out
    }

    /// The most recently added matrix stored under `name`, or `nil` if none exists.
    public func matrixData(named name: String) async throws -> Data? {
        try requireComponent(.matrices, "matrices")
        let connection = try requireConnection()
        let stmt = try connection.prepare("""
            SELECT data FROM matrices WHERE name = ? ORDER BY ordinal DESC LIMIT 1
            """)
        stmt.bind(name, at: 1)
        guard try stmt.step() else { return nil }
        return Data(stmt.columnBlob(at: 0))
    }

    private func nextMatrixOrdinal(connection: SQLiteConnection) throws -> Int {
        let stmt = try connection.prepare("SELECT COALESCE(MAX(ordinal), -1) + 1 FROM matrices")
        _ = try stmt.step()
        return stmt.columnInt(at: 0)
    }

    private func makeMatrixInfo(stmt: Statement, formatter: ISO8601DateFormatter) throws -> StoredMatrixInfo {
        let uuidString = stmt.columnText(at: 0)
        guard let uuid = UUID(uuidString: uuidString) else {
            throw PersistenceError.corruptData("invalid matrix uuid: \(uuidString)")
        }
        let createdAtString = stmt.columnText(at: 3)
        guard let createdAt = formatter.date(from: createdAtString) else {
            throw PersistenceError.corruptData("invalid matrix created_at: \(createdAtString)")
        }
        return StoredMatrixInfo(id: uuid, name: stmt.columnText(at: 1),
                                 description: stmt.columnIsNull(at: 2) ? nil : stmt.columnText(at: 2),
                                 createdAt: createdAt)
    }
}
