//
//  GraphExampleData.swift
//  DyerlabFoundation
//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//
//  Bundled example graph data (see `Data/` resources, wired via `Package.swift`).
//

import Foundation

/// Locates bundled `Data/` resource files for this package's example graphs.
public enum GraphExampleData {

    public enum LoadError: LocalizedError {
        case resourceMissing(String)

        public var errorDescription: String? {
            switch self {
            case .resourceMissing(let name):
                return "Bundled example-data resource '\(name)' could not be found."
            }
        }
    }

    /// The URL of a bundled `Data/` resource file.
    ///
    /// - Parameters:
    ///   - name: File name without its extension (e.g. `"lopho"`).
    ///   - ext: File extension without the leading dot (e.g. `"geojson"`).
    public static func url(_ name: String, extension ext: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Data") else {
            throw LoadError.resourceMissing("\(name).\(ext)")
        }
        return url
    }
}
