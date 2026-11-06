//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GraphsFileError.swift
//  PopulationGenetics
//
//  Why a `.graphs` file couldn't be read or updated.
//
//  Created by Rodney Dyer on 2026.11.05.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Why a `.graphs` file couldn't be read or updated.
public enum GraphsFileError: LocalizedError, Equatable {
    /// The file holds no population graph.
    case noGraph
    /// The file's nodes no longer match the graph being saved, usually because
    /// another program replaced its graph after it was opened.
    case nodesChanged

    /// A user-presentable description of the failure.
    public var errorDescription: String? {
        switch self {
        case .noGraph:
            "This file has no population graph."
        case .nodesChanged:
            "The graph in this file has changed since it was opened. Close and reopen it, then import the attributes again."
        }
    }
}
