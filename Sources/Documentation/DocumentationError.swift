//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DocumentationError.swift
//  Documentation
//
//  Why an app's help couldn't be read.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// A failure to read an app's help index.
public enum DocumentationError: LocalizedError, Equatable, Sendable {
    /// The app has no help index under the expected name.
    case missingIndex(String)
    /// The index file exists but couldn't be read.
    case unreadableIndex(String)
    /// The index file isn't a help index; the second value is the decoder's reason.
    case malformedIndex(String, String)

    /// A description of the failure.
    public var errorDescription: String? {
        switch self {
        case .missingIndex(let name): "The help index “\(name)” isn't in the app."
        case .unreadableIndex(let name): "The help index “\(name)” couldn't be read."
        case .malformedIndex(let name, _): "The help index “\(name)” isn't in the expected format."
        }
    }

    /// What went wrong in more detail, where there is more to say.
    public var failureReason: String? {
        if case .malformedIndex(_, let reason) = self { return reason }
        return nil
    }
}
