//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CSVDocumentTests.swift
//  PresentationZenTests
//
//  Created by Rodney Dyer on 2026.10.28.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
@testable import PresentationZen

@Suite("CSVDocument")
struct CSVDocumentTests {

    @Test("keeps its initial text")
    func initialText() {
        #expect(CSVDocument(initialText: "a,b\n1,2").text == "a,b\n1,2")
    }

    @Test("quoted(_:) matches String.csvQuoted")
    func quoting() {
        #expect(CSVDocument.quoted("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }
}
