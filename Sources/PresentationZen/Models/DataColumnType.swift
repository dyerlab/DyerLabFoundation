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
//  DataColumnType.swift
//  
//
//  Created by Rodney Dyer on 2024-02-16.
//

import Foundation

public enum DataColumnType: String  {
    case label = "Label"
    case category = "Category"
    case grouping = "Grouping"
    case xValue = "X"
    case yValue = "Y"
    case date = "Date"
}
