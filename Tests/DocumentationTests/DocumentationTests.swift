//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationTests.swift
//  DocumentationTests
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import Documentation

@MainActor
struct DocumentationTests {

    // MARK: - Index

    @Test func sectionsInheritTheirPage() throws {
        let library = DocumentationLibrary.sample
        #expect(library.error == nil)
        let selfing = try #require(library.index.entry("sample.selfing"))
        #expect(selfing.file == "inbreeding.html" && selfing.anchor == "sec-selfing")
        #expect(selfing.url?.host() == "dyerlabteaching.github.io")
        #expect(library.index.ancestors(of: "sample.selfing") == ["background", "sample.inbreeding"])
        #expect(library.index.ancestors(of: "nothing").isEmpty)
    }

    @Test func onlyIdAndTitleAreRequired() throws {
        let json = #"{ "title": "Help", "entries": [ { "id": "a", "title": "A", "children": [] } ] }"#
        let index = try JSONDecoder().decode(DocumentationIndex.self, from: Data(json.utf8))
        let entry = try #require(index.entries.first)
        #expect(entry.keywords.isEmpty && entry.children == nil && !entry.hasPage && index.home == nil)
    }

    @Test func aMissingIndexIsReported() {
        let library = DocumentationLibrary(bundled: "no-such-index", title: "Help", bundle: .main)
        #expect(library.error == .missingIndex("no-such-index.json"))
        #expect(library.index.entries.isEmpty && library.index.title == "Help")
    }

    // MARK: - Pages

    @Test func bundledPagesArePreferredToOnlineOnes() throws {
        let library = DocumentationLibrary.sample
        let inbreeding = try #require(library.index.entry("sample.inbreeding"))
        #expect(library.page(of: inbreeding)?.isFileURL == true)
        let online = DocumentationEntry(id: "o", title: "O", file: "missing.html",
                                        url: URL(string: "https://example.org/o.html"))
        #expect(library.page(of: online)?.host() == "example.org")
        let unwritten = try #require(library.index.entry("sample.structure"))
        #expect(library.page(of: unwritten) == nil)
    }

    @Test func showingATopicOpensTheRowsAboveIt() {
        let library = DocumentationLibrary.sample
        #expect(library.selection == "sample.welcome")
        library.expanded = []
        library.query = "selfing"
        library.show("sample.wahlund")
        #expect(library.selection == "sample.wahlund" && library.query.isEmpty)
        #expect(library.expanded == ["background", "sample.inbreeding"])
        library.show("nothing")
        #expect(library.selection == "sample.wahlund")
    }

    // MARK: - Search

    @Test func titlesMatchBeforeText() async {
        let library = DocumentationLibrary.sample
        #expect(library.results(for: "WAHLUND").map(\.id) == ["sample.wahlund"])
        #expect(library.results(for: "heterozygosity").map(\.id) == ["sample.inbreeding"])
        #expect(library.results(for: "  ").isEmpty)
        #expect(library.results(for: "demes").isEmpty)

        await library.loadSearchText()
        let demes = library.results(for: "demes hardy weinberg")
        #expect(demes.map(\.id) == ["sample.inbreeding"] && demes.first?.match == .text)
        #expect(demes.first?.path == ["Background"])
        let wahlund = library.results(for: "wahlund")
        #expect(wahlund.map(\.id) == ["sample.wahlund", "sample.inbreeding"])
        #expect(library.results(for: "scriptonlyword").isEmpty, "script contents aren't searched")
    }

    @Test func htmlIsReducedToFoldedText() {
        let html = """
        <html><head><style>p { color: red }</style></head>
        <body><!-- note --><p>Hardy&ndash;Weinberg&nbsp;Équilibre &#946; &#x3B8;</p><script>x()</script></body></html>
        """
        #expect(DocumentationText.plainText(fromHTML: html) == "hardy weinberg equilibre β θ")
    }
}
