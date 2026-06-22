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
//  DataPointProvider.swift
//  
//
//  Created by Rodney Dyer on 2/17/24.
//

import Foundation


/**
 Protocol indicating that the object produces data types of some sort.
 */
public protocol DataPointProvider {
    
    /// Sole variable required to be a DataPointProvider
    var dataPoints: [DataPoint] { get }
    
}
