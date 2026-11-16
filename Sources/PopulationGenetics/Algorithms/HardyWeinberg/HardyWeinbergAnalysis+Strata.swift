//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  HardyWeinbergAnalysis+Strata.swift
//  PopulationGenetics
//
//  gstudio's hwe.test(x, stratum =, loci =) table: one test per stratum and
//  locus, over the adults (offspring repeat their mothers' alleles, as in
//  `StratumReport`).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

public extension HardyWeinbergAnalysis {

    /// One test per stratum and locus, as gstudio's `hwe.test()` tabulates them.
    ///
    /// - Parameters:
    ///   - dataset: The genotypes, with strata.
    ///   - level: The strata level, or `nil` (the default) to test the adults as a whole.
    ///   - loci: The locus ordinals, or `nil` (the default) for every locus.
    /// - Returns: The tests in stratum order (first met in the data), then locus order; a locus that can't be
    ///   tested in a stratum (no genotypes, or a single allele) is left out.
    static func tests(dataset: ImportedDataset, level: String? = nil, loci: [Int]? = nil) -> [HardyWeinbergAnalysis] {
        let used = loci ?? Array(dataset.matrix.loci.indices)
        guard let level else {
            return used.compactMap { HardyWeinbergAnalysis(matrix: dataset.matrix, locus: $0,
                                                           over: dataset.adultOrdinals) }
        }
        return StratumReport.strata(of: level, in: dataset).flatMap { name in
            let adults = StratumReport(dataset: dataset, level: level, name: name).adults
            return used.compactMap { HardyWeinbergAnalysis(matrix: dataset.matrix, locus: $0, over: adults,
                                                           stratum: name) }
        }
    }
}
