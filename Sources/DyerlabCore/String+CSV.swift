//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  String+CSV.swift
//  DyerlabCore
//
//  Created by Rodney Dyer on 2026.10.28.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

public extension String {

    /// The string quoted as a CSV field: wrapped in double quotes, with any quotes inside doubled.
    ///
    /// Follows RFC 4180, so commas, quotes, and line breaks in the value are preserved.
    var csvQuoted: String {
        "\"" + replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
