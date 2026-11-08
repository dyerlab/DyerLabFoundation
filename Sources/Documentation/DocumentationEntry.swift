//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationEntry.swift
//  Documentation
//
//  One row of a help index's outline: a group of topics, a page, or a
//  section of a page. A page is a bundled HTML file, an online URL, or both,
//  in which case the bundled file is shown and the URL offered as the full
//  version online. A section names an anchor in its page, and an entry with
//  neither file nor URL is a group, or a topic still to be written.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A group, page or section in a help index.
public struct DocumentationEntry: Codable, Hashable, Identifiable, Sendable {

    /// The entry's identifier, unique in its index, which help links name.
    public let id: String
    /// The title shown in the outline and over the page.
    public let title: String
    /// A sentence describing the entry, shown on its group's overview.
    public let summary: String?
    /// The page's HTML file, relative to the index file.
    public let file: String?
    /// The page's online address.
    public let url: URL?
    /// The element id the entry scrolls to within its page.
    public let anchor: String?
    /// The SF Symbol shown beside the title.
    public let symbol: String?
    /// Extra words the search matches.
    public let keywords: [String]
    /// The entries under this one; `nil` for a leaf.
    public let children: [DocumentationEntry]?

    private enum CodingKeys: String, CodingKey {
        case id, title, summary, file, url, anchor, symbol, keywords, children
    }

    // MARK: - Initialization

    /// Creates an entry.
    ///
    /// - Parameters:
    ///   - id: The entry's identifier, unique in its index.
    ///   - title: The title shown in the outline and over the page.
    ///   - summary: A sentence describing the entry.
    ///   - file: The page's HTML file, relative to the index file.
    ///   - url: The page's online address.
    ///   - anchor: The element id the entry scrolls to within its page.
    ///   - symbol: The SF Symbol shown beside the title.
    ///   - keywords: Extra words the search matches.
    ///   - children: The entries under this one; `nil` for a leaf.
    public init(id: String, title: String, summary: String? = nil, file: String? = nil, url: URL? = nil,
                anchor: String? = nil, symbol: String? = nil, keywords: [String] = [],
                children: [DocumentationEntry]? = nil) {
        self.id = id
        self.title = title
        self.summary = summary
        self.file = file
        self.url = url
        self.anchor = anchor
        self.symbol = symbol
        self.keywords = keywords
        self.children = children
    }

    /// Decodes an entry; only `id` and `title` are required.
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: A `DecodingError` when `id` or `title` is missing.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        file = try container.decodeIfPresent(String.self, forKey: .file)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        anchor = try container.decodeIfPresent(String.self, forKey: .anchor)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        let children = try container.decodeIfPresent([DocumentationEntry].self, forKey: .children)
        self.children = children?.isEmpty == true ? nil : children
    }

    // MARK: - Contents

    /// Whether the entry has a page of its own to show.
    public var hasPage: Bool {
        file != nil || url != nil
    }

    /// The entry with its pages inherited: a section with no file or URL of its own uses its parent's.
    ///
    /// - Parameter parent: The entry this one sits under.
    /// - Returns: The entry, with the parent's file and URL where it names an anchor but no page.
    func inheriting(from parent: DocumentationEntry) -> DocumentationEntry {
        guard !hasPage, anchor != nil else { return self }
        return DocumentationEntry(id: id, title: title, summary: summary, file: parent.file, url: parent.url,
                                  anchor: anchor, symbol: symbol, keywords: keywords, children: children)
    }
}
