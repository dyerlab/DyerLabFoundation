//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphExampleData.swift
//  Graph
//
//  Bundled example graph data (see `Data/` resources, wired via `Package.swift`).
//
//  Created by Rodney Dyer on 2026.08.08.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Locates bundled `Data/` resource files for this package's example graphs.
public enum GraphExampleData {

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

    /// The URL of a bundled `Data/` resource file.
    ///
    /// - Parameters:
    ///   - name: File name without its extension (e.g. `"lopho"`).
    ///   - ext: File extension without the leading dot (e.g. `"geojson"`).
    /// - Returns: The resource's URL in the module bundle.
    /// - Throws: ``LoadError/resourceMissing(_:)`` if the bundle has no such file.
    public static func url(_ name: String, extension ext: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Data") else {
            throw LoadError.resourceMissing("\(name).\(ext)")
        }
        return url
    }
}
