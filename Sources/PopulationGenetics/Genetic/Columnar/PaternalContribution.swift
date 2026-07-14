//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PaternalContribution.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 6/28/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

/// The outcome of recovering the paternal gamete from a mother/offspring pair.
public enum PaternalContribution: Sendable, Equatable {
    /// The mother or offspring genotype was not a complete diploid genotype.
    case missing
    /// The offspring is incompatible with the mother (no allele could be maternal).
    case impossible
    /// A single, unambiguous paternal allele index.
    case resolved(UInt8)
    /// Two equally possible paternal alleles (offspring matches the mother's
    /// heterozygote), stored in ascending order.
    case ambiguous(UInt8, UInt8)
}
