//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationIndex.swift
//  Documentation
//
//  The JSON file that describes an app's help: its title, the page shown
//  first, and the outline of groups, pages and sections. The index is written
//  by whatever builds the pages (for GeneticStudio, the Quarto assembler that
//  renders the course modules), so the app only reads it. Sections inherit
//  their page from the entry above them, so the generator need only list
//  anchors under a page.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// An app's help outline, read from a JSON index file.
public struct DocumentationIndex: Codable, Hashable, Sendable {

    /// The help's title, such as "GeneticStudio Help".
    public let title: String
    /// The id of the entry shown when the help opens.
    public let home: String?
    /// The top-level entries of the outline.
    public let entries: [DocumentationEntry]

    // MARK: - Initialization

    /// Creates an index.
    ///
    /// - Parameters:
    ///   - title: The help's title.
    ///   - home: The id of the entry shown when the help opens.
    ///   - entries: The top-level entries of the outline.
    public init(title: String, home: String? = nil, entries: [DocumentationEntry]) {
        self.title = title
        self.home = home
        self.entries = entries.map { Self.resolving($0) }
    }

    /// Decodes an index, passing each page down to the sections under it.
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: A `DecodingError` when the file isn't an index.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(title: try container.decode(String.self, forKey: .title),
                  home: try container.decodeIfPresent(String.self, forKey: .home),
                  entries: try container.decode([DocumentationEntry].self, forKey: .entries))
    }

    /// Reads an index file.
    ///
    /// - Parameter url: The index file.
    /// - Throws: `DocumentationError` when the file can't be read or isn't an index.
    public init(contentsOf url: URL) throws(DocumentationError) {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw .unreadableIndex(url.lastPathComponent)
        }
        do {
            self = try JSONDecoder().decode(DocumentationIndex.self, from: data)
        } catch {
            throw .malformedIndex(url.lastPathComponent, error.localizedDescription)
        }
    }

    private static func resolving(_ entry: DocumentationEntry) -> DocumentationEntry {
        guard let children = entry.children else { return entry }
        return DocumentationEntry(id: entry.id, title: entry.title, summary: entry.summary, file: entry.file,
                                  url: entry.url, anchor: entry.anchor, symbol: entry.symbol,
                                  keywords: entry.keywords,
                                  children: children.map { resolving($0.inheriting(from: entry)) })
    }

    // MARK: - Lookup

    /// Every entry, depth first, each with the titles of the entries above it.
    public var flattened: [(entry: DocumentationEntry, path: [String])] {
        var result: [(DocumentationEntry, [String])] = []
        func visit(_ entries: [DocumentationEntry], path: [String]) {
            for entry in entries {
                result.append((entry, path))
                visit(entry.children ?? [], path: path + [entry.title])
            }
        }
        visit(entries, path: [])
        return result
    }

    /// The entry with an id.
    ///
    /// - Parameter id: The entry's id.
    /// - Returns: The entry, or `nil` when the index has none with that id.
    public func entry(_ id: DocumentationEntry.ID) -> DocumentationEntry? {
        flattened.first { $0.entry.id == id }?.entry
    }

    /// The ids of the entries above an entry, outermost first.
    ///
    /// - Parameter id: The entry's id.
    /// - Returns: Its ancestors' ids, empty for a top-level entry or an unknown id.
    public func ancestors(of id: DocumentationEntry.ID) -> [DocumentationEntry.ID] {
        func search(_ entries: [DocumentationEntry], path: [DocumentationEntry.ID]) -> [DocumentationEntry.ID]? {
            for entry in entries {
                if entry.id == id { return path }
                if let found = search(entry.children ?? [], path: path + [entry.id]) { return found }
            }
            return nil
        }
        return search(entries, path: []) ?? []
    }
}
