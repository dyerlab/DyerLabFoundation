//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  KamadaKawaiError.swift
//  Graph
//
//  Created by Rodney Dyer on 2026.10.23.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Errors thrown while setting up a Kamada–Kawai layout.
public enum KamadaKawaiError: LocalizedError, Equatable {

    /// igraph requires strictly positive edge lengths; the payload is the offending weight.
    case nonPositiveWeight(Double)

    /// A user-presentable description of the failure.
    public var errorDescription: String? {
        switch self {
        case .nonPositiveWeight(let weight):
            "Kamada–Kawai layout needs positive edge lengths, but found \(weight)."
        }
    }
}
