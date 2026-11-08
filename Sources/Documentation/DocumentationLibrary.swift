//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationLibrary.swift
//  Documentation
//
//  An app's help as the browser sees it: the index, the folder its pages are
//  in, which entry is showing and which outline rows are open. One library
//  is shared by the help window and every help link, so a link in a document
//  window turns the help window to its topic. A page bundled with the app is
//  preferred to its online copy, so help works offline; a topic with only a
//  URL is shown from the web until its page is bundled.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Observation

/// An app's help: its index, its pages, and what the browser is showing.
@MainActor
@Observable
public final class DocumentationLibrary {

    /// The help's outline.
    public let index: DocumentationIndex
    /// The folder the index's file paths are relative to.
    public let folder: URL?
    /// Why the index couldn't be read, when it couldn't.
    public let error: DocumentationError?

    /// The entry the browser shows.
    public var selection: DocumentationEntry.ID?
    /// The outline rows that are open.
    public var expanded: Set<DocumentationEntry.ID>
    /// The search text.
    public var query = ""

    /// The searchable text of each bundled page, by file, once read.
    private var pageText: [String: String] = [:]
    /// Whether the bundled pages have been read for searching.
    public private(set) var isTextLoaded = false

    // MARK: - Initialization

    /// Creates a library from an index already read.
    ///
    /// - Parameters:
    ///   - index: The help's outline.
    ///   - folder: The folder the index's file paths are relative to.
    public init(index: DocumentationIndex, folder: URL?) {
        self.index = index
        self.folder = folder
        self.error = nil
        self.selection = index.home ?? index.entries.first?.id
        self.expanded = Set(index.entries.filter { $0.children != nil && !$0.hasPage }.map(\.id))
    }

    /// Creates a library from an index file; its pages are looked for beside it.
    ///
    /// - Parameter indexURL: The index file.
    public convenience init(contentsOf indexURL: URL) {
        do {
            self.init(index: try DocumentationIndex(contentsOf: indexURL), folder: indexURL.deletingLastPathComponent())
        } catch {
            self.init(failure: error, title: "Help")
        }
    }

    /// Creates a library from an index bundled with the app.
    ///
    /// - Parameters:
    ///   - name: The index file's name, without its `json` extension.
    ///   - title: The help's title, used if the index can't be read.
    ///   - bundle: The bundle holding the index and its pages.
    public convenience init(bundled name: String, title: String, bundle: Bundle = .main) {
        if let url = bundle.url(forResource: name, withExtension: "json") {
            self.init(contentsOf: url)
        } else {
            self.init(failure: .missingIndex("\(name).json"), title: title)
        }
    }

    /// An empty library recording why it couldn't be read.
    private init(failure: DocumentationError, title: String) {
        self.index = DocumentationIndex(title: title, entries: [])
        self.folder = nil
        self.error = failure
        self.selection = nil
        self.expanded = []
    }

    /// A small help bundled with this package, for previews and tests.
    public static var sample: DocumentationLibrary {
        guard let url = Bundle.module.url(forResource: "index", withExtension: "json", subdirectory: "SampleHelp") else {
            return DocumentationLibrary(index: DocumentationIndex(title: "Sample Help", entries: []), folder: nil)
        }
        return DocumentationLibrary(contentsOf: url)
    }

    // MARK: - Pages

    /// The selected entry.
    public var selectedEntry: DocumentationEntry? {
        selection.flatMap(index.entry)
    }

    /// The bundled page of an entry, when the app has its file.
    ///
    /// - Parameter entry: The entry.
    /// - Returns: The file's URL, without the entry's anchor.
    public func bundledPage(of entry: DocumentationEntry) -> URL? {
        guard let file = entry.file, let folder else { return nil }
        let url = folder.appending(path: file)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    /// Where the browser loads an entry from: its bundled page if there is one, otherwise its online page.
    ///
    /// - Parameter entry: The entry.
    /// - Returns: The page's URL, without the entry's anchor, or `nil` when the entry has no page yet.
    public func page(of entry: DocumentationEntry) -> URL? {
        bundledPage(of: entry) ?? entry.url
    }

    // MARK: - Navigation

    /// Shows an entry, opening the outline rows above it.
    ///
    /// - Parameter id: The entry's id; an id the index doesn't have changes nothing.
    public func show(_ id: DocumentationEntry.ID) {
        guard index.entry(id) != nil else { return }
        expanded.formUnion(index.ancestors(of: id))
        query = ""
        selection = id
    }

    // MARK: - Search

    /// The entries matching the search text: title matches first, then pages whose text matches.
    public var results: [DocumentationSearchResult] {
        results(for: query)
    }

    /// The entries matching a search.
    ///
    /// Every word of the search must appear. An entry matches on its title, keywords and summary;
    /// a page (an entry with a file and no anchor) also matches on its text, once that has been
    /// read with ``loadSearchText()``.
    ///
    /// - Parameter query: The search text.
    /// - Returns: The matching entries, title matches first, each group in outline order.
    public func results(for query: String) -> [DocumentationSearchResult] {
        let terms = DocumentationText.folded(query).split(separator: " ").map(String.init)
        guard !terms.isEmpty else { return [] }
        let found = index.flattened.compactMap { entry, path -> DocumentationSearchResult? in
            let label = DocumentationText.folded(([entry.title, entry.summary ?? ""] + entry.keywords)
                .joined(separator: " "))
            if terms.allSatisfy(label.contains) {
                return DocumentationSearchResult(entry: entry, path: path, match: .title)
            }
            if entry.anchor == nil, let file = entry.file, let text = pageText[file], terms.allSatisfy(text.contains) {
                return DocumentationSearchResult(entry: entry, path: path, match: .text)
            }
            return nil
        }
        return found.filter { $0.match == .title } + found.filter { $0.match == .text }
    }

    /// Reads the bundled pages' text so the search can match it; later calls do nothing.
    public func loadSearchText() async {
        guard !isTextLoaded else { return }
        let pages = index.flattened.compactMap { entry, _ -> (String, URL)? in
            guard entry.anchor == nil, let file = entry.file, let url = bundledPage(of: entry) else { return nil }
            return (file, url)
        }
        pageText = await Task.detached(priority: .utility) {
            var text: [String: String] = [:]
            for (file, url) in pages where text[file] == nil {
                guard let html = try? String(contentsOf: url, encoding: .utf8) else { continue }
                text[file] = DocumentationText.plainText(fromHTML: html)
            }
            return text
        }.value
        isTextLoaded = true
    }
}
