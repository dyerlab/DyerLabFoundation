//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ExampleData.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Raw-text access to the bundled example-data files themselves, for callers
/// pinned to exact file content (e.g. regression tests).
public enum ExampleData {

    /// Errors thrown when a bundled resource can't be located.
    public enum LoadError: LocalizedError {
        /// The named resource file isn't in the module bundle.
        case resourceMissing(String)

        public var errorDescription: String? {
            switch self {
            case .resourceMissing(let name):
                return "Bundled example-data resource '\(name)' could not be found."
            }
        }
    }

    /// Reads a bundled `ExampleData/` resource file as UTF-8 text.
    ///
    /// - Parameters:
    ///   - name: File name without its extension (e.g. `"phylog.012"` for `phylog.012.indv`).
    ///   - ext: File extension without the leading dot (e.g. `"indv"`).
    /// - Returns: The file's contents.
    /// - Throws: ``LoadError/resourceMissing(_:)`` if the bundle has no such file, or the error from reading it as
    ///   UTF-8.
    public static func text(_ name: String, extension ext: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "ExampleData") else {
            throw LoadError.resourceMissing("\(name).\(ext)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
