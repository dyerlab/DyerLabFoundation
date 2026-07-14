// The Swift Programming Language
// https://docs.swift.org/swift-book
//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Copyright (c) 2021-2025 The Dyer Laboratory.  All Rights Reserved.
//
//  PopulationGenetics.swift
//  Created by Rodney Dyer on 3/2/25.

/// A high-performance engine for population and landscape genetics analysis.
///
/// PopulationGenetics stores and analyzes diploid marker data at scales from a few
/// microsatellite loci to chromosome-scale SNP panels. Genotypes are held
/// locus-major as packed columns of `UInt8` allele indices addressed by individual
/// ordinal, so the same machinery serves both marker classes.
///
/// ## Columnar core
///
/// - ``AlleleCodebook`` — per-locus allele index ↔ label map; index `0` is the
///   NULL / missing allele in both SNP and microsatellite data.
/// - ``GenotypeColumn`` — locus-major column protocol, implemented by
///   ``BiallelicColumn`` (2-bit packed SNP dosage, four genotypes per byte) and
///   ``MultiallelicColumn`` (microsatellite `UInt8` allele-index pairs).
/// - ``AlleleFrequencies`` — incremental, value-type allele-count accumulator with
///   symmetric `add`/`remove` and diversity statistics (`A`, `A95`, `Ae`, `Ho`, `He`).
/// - ``PollenPoolFrequencies`` / ``paternalGamete(offspring:mother:)`` — maternal
///   subtraction for mother/offspring parentage and pollen-pool analysis.
///
/// A statistic is a column reduced over a set of individual ordinals, so groupings
/// (strata) and permutation / null models are simply different index sets.
///
/// ## Ergonomic access
///
/// ``PopGenStore`` is a facade over the columnar core: growable staging arrays
/// that support incremental `add`/`set` mutation (SwiftUI apps, importers,
/// simulations), materializing a ``GenotypeMatrix`` on demand for algorithms and
/// SQLite persistence via `GenotypeMatrixStore`. The legacy UUID object-graph
/// store (`PopGenDataSet`, `PopGenDataStore`) has been retired.
