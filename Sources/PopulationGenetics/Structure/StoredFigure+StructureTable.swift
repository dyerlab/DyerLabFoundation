//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StoredFigure+StructureTable.swift
//  PopulationGenetics
//
//  A structure table is saved as a figure of form `table`, generator
//  `amova_table`, with its `StructureSpec` as JSON in `spec`.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import PresentationZen

public extension FigureGenerator {
    /// A structure table: ``StructureSpec`` JSON in the figure's `spec`.
    static let amovaTable = FigureGenerator(rawValue: "amova_table")
}

public extension StoredFigure {

    /// Creates a figure from a structure table.
    ///
    /// - Parameters:
    ///   - id: The figure's identity.
    ///   - title: The table's title.
    ///   - legend: The table's legend.
    ///   - source: The program making the figure.
    ///   - result: The table.
    ///   - createdAt: When the figure was made.
    /// - Throws: `EncodingError` if the parameters can't be encoded.
    init(id: UUID = UUID(),
         title: String,
         legend: String,
         source: String,
         result: StructureResult,
         createdAt: Date = Date()) throws {
        self.init(id: id, title: title, legend: legend, source: source, createdAt: createdAt)
        try setStructureResult(result)
    }

    /// The figure's structure parameters, or `nil` if it isn't a structure table this version can read.
    var structureSpec: StructureSpec? {
        guard generator == .amovaTable, let spec else { return nil }
        return try? JSONDecoder().decode(StructureSpec.self, from: Data(spec.utf8))
    }

    /// Makes the figure a structure table holding this result.
    ///
    /// - Parameter result: The table.
    /// - Throws: `EncodingError` if the parameters can't be encoded.
    mutating func setStructureResult(_ result: StructureResult) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        generator = .amovaTable
        spec = String(decoding: try encoder.encode(result.spec), as: UTF8.self)
        storeTable(result.dataTable, notes: result.report.notes.map(\.message))
    }
}
