//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MarkerType.swift
//  PopulationGenetics
//
//  Columnar core: the kind of genetic marker a locus represents. Drives which
//  packed column representation backs the locus.
//
//  Created by Rodney Dyer on 2026.07.14.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The class of genetic marker stored at a locus.
///
/// This determines the physical packing used by the columnar store:
/// - `.biallelicSNP` → 2-bit dosage packing (`BiallelicColumn`)
/// - `.microsatellite` → `UInt8` allele-index pairs (`MultiallelicColumn`)
public enum MarkerType: String, Codable, Sendable, CaseIterable {
    /// A biallelic single-nucleotide polymorphism (reference / alternate).
    case biallelicSNP
    /// A multiallelic microsatellite / SSR locus.
    case microsatellite
}
