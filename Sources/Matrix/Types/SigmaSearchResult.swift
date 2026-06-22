//
//  File.swift
//  MatrixStuff
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
//  Created by Rodney Dyer on 2/3/26.
//

import Foundation

/*
 Result structure for finding optimized sigma for ``tSNEAffinity``
 */
public struct SigmaSearchResult {
    
    /// Precision permameter (2 sigma^2)^-1
    let beta: Double
    
    /// conditional probabilty distribution
    let probabilities: [Double]
    
    /// Acheived perplexity
    let perplexity: Double
    
    /// Number o fiterations
    let iterations: Int
}
