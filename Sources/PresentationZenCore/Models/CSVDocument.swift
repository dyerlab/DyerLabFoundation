//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  CSVDocument.swift
//  PresentationZen
//
//  Created by Rodney Dyer on 2024.05.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// A comma-separated text file, for use with `fileExporter` and `fileImporter`.
///
/// ```swift
/// .fileExporter(isPresented: $exporting,
///               document: CSVDocument(initialText: csv),
///               contentType: .commaSeparatedText,
///               defaultFilename: "data.csv") { _ in }
/// ```
public struct CSVDocument: FileDocument {

    // MARK: - Properties

    /// The content types this document can open: CSV only.
    public static let readableContentTypes = [UTType.commaSeparatedText]
    /// The content types this document can save: CSV only.
    public static let writableContentTypes = [UTType.commaSeparatedText]

    /// The full CSV text of the document.
    public var text: String = ""

    // MARK: - Initializers

    /// Creates a document for export.
    /// - Parameter initialText: The CSV text to write. Defaults to an empty string.
    public init(initialText: String = "") {
        text = initialText
    }

    /// Reads a document from disk, decoding the file contents as UTF-8.
    /// - Parameter configuration: The read configuration provided by SwiftUI.
    public init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        }
    }

    // MARK: - Conformance

    /// Writes ``text`` to disk as UTF-8.
    /// - Parameter configuration: The write configuration provided by SwiftUI.
    /// - Returns: A file wrapper containing the encoded text.
    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

public extension CSVDocument {

    /// Quotes a value for CSV: wraps it in double quotes and doubles any quotes inside.
    ///
    /// Follows RFC 4180, so commas, quotes, and line breaks in the value are preserved.
    /// - Parameter value: The raw field value.
    /// - Returns: The quoted field.
    static func quoted(_ value: String) -> String {
        value.csvQuoted
    }
}
