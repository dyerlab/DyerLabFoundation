//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  importVCFTools012.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//
//  Imports the three-file output of `vcftools --012`, which encodes biallelic
//  SNP dosage with no allele identity at all (only CHROM/POS, never REF/ALT
//  bases). Every locus this importer produces is tagged
//  `Locus.AlleleProvenance.refAltPlaceholder` with a fixed `Z` (REF-slot) /
//  `z` (ALT-slot) codebook — see `Locus.AlleleProvenance` for why this is
//  REF/ALT identity, not major/minor.
//

import Foundation

/// Imports a `vcftools --012` triplet into a `GenotypeMatrix`.
///
/// - Parameters:
///   - dosageText: Contents of the `.012` file — one row per individual, tab-separated,
///     column 0 is the 0-based row index (dropped), remaining columns are dosage
///     codes in `{-1, 0, 1, 2}` (missing, hom-ref, het, hom-alt), one per site.
///   - indvText: Contents of the `.012.indv` file — one sample name per line, in
///     the same row order as `dosageText`.
///   - posText: Contents of the `.012.pos` file — one `CHROM\tPOS` pair per line,
///     in the same column order as `dosageText`'s dosage columns.
/// - Returns: The parsed matrix. `parentage` and `strata` are always empty —
///   neither exists in this triplet.
public func importVCFTools012(dosageText: String, indvText: String, posText: String) throws -> ImportedDataset {

    let sampleNames = indvText.split(separator: "\n", omittingEmptySubsequences: true)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard !sampleNames.isEmpty else { throw GenotypeImportError.emptyInput }

    let posLines = posText.split(separator: "\n", omittingEmptySubsequences: true)
    guard !posLines.isEmpty else { throw GenotypeImportError.emptyInput }

    var loci: [Locus] = []
    loci.reserveCapacity(posLines.count)
    for line in posLines {
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard fields.count >= 2 else {
            throw GenotypeImportError.malformedGenotype(locus: String(line), row: 0, value: String(line))
        }
        let contig = fields[0].trimmingCharacters(in: .whitespaces)
        let position = fields[1].trimmingCharacters(in: .whitespaces)
        loci.append(Locus(name: "\(contig):\(position)", location: UInt(position) ?? 0,
                           contig: contig, alleleProvenance: .refAltPlaceholder))
    }

    let dosageRows = dosageText.split(separator: "\n", omittingEmptySubsequences: true)
    guard dosageRows.count == sampleNames.count else {
        throw GenotypeImportError.sideFileMismatch(expected: sampleNames.count, found: dosageRows.count, file: ".012.indv")
    }

    var codes = [[UInt8]](repeating: [UInt8](repeating: 0, count: sampleNames.count), count: loci.count)

    for (rowNumber, line) in dosageRows.enumerated() {
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
        // fields[0] is the vcftools row index; the remaining fields are dosage codes.
        guard fields.count - 1 == loci.count else {
            throw GenotypeImportError.sideFileMismatch(expected: loci.count, found: fields.count - 1, file: ".012.pos")
        }
        for locusIndex in 0..<loci.count {
            let raw = fields[locusIndex + 1].trimmingCharacters(in: .whitespaces)
            guard let vcftoolsCode = Int(raw), (-1...2).contains(vcftoolsCode) else {
                throw GenotypeImportError.invalidDosageCode(row: rowNumber, column: locusIndex, value: raw)
            }
            codes[locusIndex][rowNumber] = UInt8(vcftoolsCode + 1)
        }
    }

    let individuals = sampleNames.map { Individual(name: $0) }
    let placeholderCodebook = AlleleCodebook(alleles: ["Z", "z"])
    let columns: [any GenotypeColumn] = codes.map { BiallelicColumn(codebook: placeholderCodebook, codes: $0) }

    let matrix = GenotypeMatrix(individuals: individuals, loci: loci, columns: columns)
    return ImportedDataset(matrix: matrix, parentage: ParentageDesign(families: []), strata: [:])
}
