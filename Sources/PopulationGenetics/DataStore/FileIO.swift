//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FileIO.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/14/25.
//

import Foundation

/// Parses a CSV-formatted string into a 2D array of strings.
///
/// This basic parser splits the input by newlines (rows) and commas (columns).
/// It does not handle quoted fields or escaped characters.
///
/// - Parameter raw: The CSV string to parse.
/// - Returns: A 2D array where each element is a row of column values.
public func csvToMatrix( raw: String ) -> [ [String] ] {

    var ret = [ [String] ]()

    for row in raw.components(separatedBy: "\n") {
        ret.append( row.components(separatedBy: ","))
    }

    return ret
}


