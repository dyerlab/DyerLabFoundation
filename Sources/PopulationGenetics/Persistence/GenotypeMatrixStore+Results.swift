//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMatrixStore+Results.swift
//  PopulationGenetics
//
//  Read/write access to the `results`/`result_images` log — a generic,
//  append-only record of Markdown analysis writeups and their attached
//  images. Platform-neutral: images are stored and returned as raw `Data`
//  here; `UIImage`/`NSImage` convenience lives in
//  `GenotypeMatrixStore+PlatformImage.swift`, gated per-platform.
//

import Foundation
import PresentationZen

extension GenotypeMatrixStore {

    /// Appends one result. Results are never updated in place; each call adds a new row.
    public func addResult(_ result: AnalysisResult) async throws {
        guard mode == .readWrite else { throw PersistenceError.readOnly }
        let connection = try requireConnection()
        let ordinal = try nextResultOrdinal(connection: connection)
        let stmt = try connection.prepare("""
            INSERT INTO results (ordinal, uuid, name, description, body, created_at) VALUES (?, ?, ?, ?, ?, ?)
            """)
        stmt.bind(ordinal, at: 1)
        stmt.bind(result.id.uuidString, at: 2)
        stmt.bind(result.name, at: 3)
        stmt.bindOptional(result.description, at: 4)
        stmt.bind(result.body, at: 5)
        stmt.bind(ISO8601DateFormatter().string(from: result.createdAt), at: 6)
        _ = try stmt.step()
        try setMetaFlag("has_results", to: true, connection: connection)
    }

    /// All results, in the order they were added.
    public func results() async throws -> [AnalysisResult] {
        let connection = try requireConnection()
        let stmt = try connection.prepare("""
            SELECT uuid, name, description, body, created_at FROM results ORDER BY ordinal
            """)
        let formatter = ISO8601DateFormatter()
        var out: [AnalysisResult] = []
        while try stmt.step() {
            out.append(try makeResult(stmt: stmt, formatter: formatter))
        }
        return out
    }

    /// A single result by id, or `nil` if none exists.
    public func result(id: UUID) async throws -> AnalysisResult? {
        let connection = try requireConnection()
        let stmt = try connection.prepare("""
            SELECT uuid, name, description, body, created_at FROM results WHERE uuid = ?
            """)
        stmt.bind(id.uuidString, at: 1)
        guard try stmt.step() else { return nil }
        return try makeResult(stmt: stmt, formatter: ISO8601DateFormatter())
    }

    /// Attaches a raw image to a result, referenceable from its Markdown body
    /// as `![alt](attachment:<image.name>)`. `(resultID, image.name)` must be
    /// unique — attaching the same name twice throws.
    public func attachImage(_ image: ResultImage, to resultID: UUID) async throws {
        guard mode == .readWrite else { throw PersistenceError.readOnly }
        let connection = try requireConnection()
        let stmt = try connection.prepare("""
            INSERT INTO result_images (result_uuid, name, mime_type, width, height, data) VALUES (?, ?, ?, ?, ?, ?)
            """)
        stmt.bind(resultID.uuidString, at: 1)
        stmt.bind(image.name, at: 2)
        stmt.bind(image.mimeType, at: 3)
        stmt.bindOptional(image.width, at: 4)
        stmt.bindOptional(image.height, at: 5)
        stmt.bind([UInt8](image.data), at: 6)
        _ = try stmt.step()
    }

    /// The image attached to a result under the given `attachment:` name, or `nil`.
    public func image(named name: String, for resultID: UUID) async throws -> ResultImage? {
        let connection = try requireConnection()
        let stmt = try connection.prepare("""
            SELECT mime_type, width, height, data FROM result_images WHERE result_uuid = ? AND name = ?
            """)
        stmt.bind(resultID.uuidString, at: 1)
        stmt.bind(name, at: 2)
        guard try stmt.step() else { return nil }
        return ResultImage(name: name, mimeType: stmt.columnText(at: 0),
                            width: stmt.columnOptionalInt(at: 1), height: stmt.columnOptionalInt(at: 2),
                            data: Data(stmt.columnBlob(at: 3)))
    }

    private func nextResultOrdinal(connection: SQLiteConnection) throws -> Int {
        let stmt = try connection.prepare("SELECT COALESCE(MAX(ordinal), -1) + 1 FROM results")
        _ = try stmt.step()
        return stmt.columnInt(at: 0)
    }

    private func makeResult(stmt: Statement, formatter: ISO8601DateFormatter) throws -> AnalysisResult {
        let uuidString = stmt.columnText(at: 0)
        guard let uuid = UUID(uuidString: uuidString) else {
            throw PersistenceError.corruptData("invalid result uuid: \(uuidString)")
        }
        let createdAtString = stmt.columnText(at: 4)
        guard let createdAt = formatter.date(from: createdAtString) else {
            throw PersistenceError.corruptData("invalid result created_at: \(createdAtString)")
        }
        return AnalysisResult(id: uuid, name: stmt.columnText(at: 1),
                               description: stmt.columnIsNull(at: 2) ? nil : stmt.columnText(at: 2),
                               body: stmt.columnText(at: 3), createdAt: createdAt)
    }
}
