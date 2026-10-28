//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ProjectMetadataTests.swift
//  PopulationGeneticsTests
//
//  Exercises ProjectStore's project metadata: the reserved identity keys and
//  app-defined key/value pairs stored in `project_metadata`.
//
//  Created by Rodney Dyer on 2026.10.24.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import PopulationGenetics

struct ProjectMetadataTests {

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".db")
    }

    @Test func createStoresIdentityAndAppMetadataTogether() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "arapat", species: "Araptus attenuatus",
                                metadata: ["collector": "RJD", "region": "Sonora"])
        let metadata = try await store.metadata()
        await store.close()

        #expect(metadata == [
            ProjectStore.MetadataKey.projectName: "arapat",
            ProjectStore.MetadataKey.species: "Araptus attenuatus",
            "collector": "RJD",
            "region": "Sonora",
        ])
    }

    @Test func identityArgumentsWinOverMetadataAndEmptyValuesAreDropped() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "arapat", species: "",
                                metadata: [ProjectStore.MetadataKey.projectName: "ignored", "empty": ""])
        let metadata = try await store.metadata()
        await store.close()

        #expect(metadata == [ProjectStore.MetadataKey.projectName: "arapat"])
    }

    @Test func setUpdateAndRemoveRoundTripThroughReopen() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "arapat", metadata: ["stale": "x"])
        try await store.setMetadata("v2", forKey: "pipeline")
        try await store.updateMetadata([
            ProjectStore.MetadataKey.projectName: "arapat-2026",
            ProjectStore.MetadataKey.description: "Cactus weevils.",
            "stale": nil,
        ])
        try await store.setMetadata("", forKey: "pipeline")
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)
        let metadata = try await reader.metadata()
        let description = try await reader.metadata(forKey: ProjectStore.MetadataKey.description)
        let summary = try await reader.readSummary()
        await reader.close()

        #expect(metadata == [
            ProjectStore.MetadataKey.projectName: "arapat-2026",
            ProjectStore.MetadataKey.description: "Cactus weevils.",
        ])
        #expect(description == "Cactus weevils.")
        #expect(summary.projectName == "arapat-2026")
        #expect(summary.species == nil)
        #expect(summary.description == "Cactus weevils.")
    }

    @Test func removingProjectNameThrowsAndChangesNothing() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "arapat")
        await #expect(throws: PersistenceError.self) {
            try await store.updateMetadata(["note": "kept?", ProjectStore.MetadataKey.projectName: nil])
        }
        let metadata = try await store.metadata()
        await store.close()

        #expect(metadata == [ProjectStore.MetadataKey.projectName: "arapat"])
    }

    @Test func readOnlyStoreRejectsMetadataWrites() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "arapat")
        await store.close()

        let reader = ProjectStore()
        try await reader.open(at: url, mode: .readOnly)
        await #expect(throws: PersistenceError.readOnly) {
            try await reader.setMetadata("x", forKey: "note")
        }
        await reader.close()
    }

    @Test func metadataIsStoredApartFromMeta() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // An app key named like a bookkeeping row must not disturb it.
        let store = ProjectStore()
        try await store.create(at: url, overwrite: true, projectName: "arapat", metadata: ["created_at": "never"])
        let summary = try await store.readSummary()
        let createdAt = try await store.metadata(forKey: "created_at")
        await store.close()

        #expect(abs(summary.createdAt.timeIntervalSinceNow) < 60)
        #expect(createdAt == "never")
    }

    @Test func snapshotRoundTripsMetadata() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try await ProjectStore.saveSnapshot(projectName: "arapat", species: "Araptus attenuatus",
                                            metadata: ["collector": "RJD"], to: url)
        let snapshot = try await ProjectStore.loadSnapshot(from: url)

        #expect(snapshot.projectName == "arapat")
        #expect(snapshot.species == "Araptus attenuatus")
        #expect(snapshot.description == nil)
        #expect(snapshot.metadata["collector"] == "RJD")
    }
}
