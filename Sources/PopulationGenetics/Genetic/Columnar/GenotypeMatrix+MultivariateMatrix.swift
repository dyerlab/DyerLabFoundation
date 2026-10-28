//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeMatrix+MultivariateMatrix.swift
//  PopulationGenetics
//
//  Columnar core: the numeric on-ramp from genotype calls into general
//  multivariate analysis (PCA, canonical discriminant analysis, `PopulationGraph`).
//  Mirrors gstudio's `to_mv()`: one numeric column per non-null allele per
//  locus, valued as that allele's dosage divided by ploidy.
//
//  Created by Rodney Dyer on 2026.08.26.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

extension GenotypeMatrix {

    /// Converts genotype calls into a numeric individuals×alleles `Matrix`.
    ///
    /// One column per non-null allele registered in each locus's codebook,
    /// named `"<locusName>_<alleleLabel>"`. A genotype's value in an allele's
    /// column is the count of that allele in the genotype divided by
    /// `ploidy` — e.g. for a biallelic SNP with alleles `A`/`B`: `AA` → `(1, 0)`,
    /// `AB` → `(0.5, 0.5)`, `BB` → `(0, 1)`. A missing genotype contributes
    /// `0` to every allele column at that locus, unless `leaveAsNA` is set,
    /// in which case it contributes `.nan`.
    ///
    /// This conversion is invariant to which allele a codebook happens to
    /// call index 1 vs. 2 (REF/ALT, major/minor, or otherwise) — downstream
    /// analyses built on the result (PCA, canonical discriminant analysis)
    /// operate on variance structure, not on allele-label semantics.
    ///
    /// - Parameters:
    ///   - ploidy: The number of alleles per genotype (default `2`).
    ///   - dropAllele: If `true`, drops each locus's last allele column
    ///     (only when that locus has more than one allele) to avoid the
    ///     exact collinearity between a locus's allele-frequency columns.
    ///   - leaveAsNA: If `true`, a missing genotype's allele columns are
    ///     `.nan` instead of `0`.
    /// - Returns: An `individualCount`×`variableCount` matrix; row names are
    ///   individual names, column names are `"<locusName>_<alleleLabel>"`.
    public func multivariateMatrix(ploidy: Int = 2, dropAllele: Bool = false, leaveAsNA: Bool = false) -> Matrix {
        var colNames: [String] = []
        var colLocusIndex: [Int] = []
        var colAlleleIndex: [UInt8] = []

        for (locusIndex, locus) in loci.enumerated() {
            let codebook = columns[locusIndex].codebook
            var indices = codebook.alleleIndices
            if dropAllele, indices.count > 1 {
                indices.removeLast()
            }
            for alleleIndex in indices {
                colNames.append("\(locus.name)_\(codebook.label(for: alleleIndex))")
                colLocusIndex.append(locusIndex)
                colAlleleIndex.append(alleleIndex)
            }
        }

        let result = Matrix(individualCount, colNames.count, 0.0)
        result.rowNames = individuals.map { $0.name }
        result.colNames = colNames

        let ploidyValue = Double(ploidy)
        for ordinal in 0..<individualCount {
            for c in 0..<colNames.count {
                let column = columns[colLocusIndex[c]]
                let alleleIndex = colAlleleIndex[c]
                guard let (left, right) = column.alleles(at: ordinal) else {
                    result[ordinal, c] = leaveAsNA ? .nan : 0.0
                    continue
                }
                let count = (left == alleleIndex ? 1 : 0) + (right == alleleIndex ? 1 : 0)
                result[ordinal, c] = Double(count) / ploidyValue
            }
        }

        return result
    }
}
