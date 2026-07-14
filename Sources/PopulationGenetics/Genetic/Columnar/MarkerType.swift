//
//  MarkerType.swift
//  PopulationGenetics
//
//  Columnar core: the kind of genetic marker a locus represents. Drives which
//  packed column representation backs the locus.
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
