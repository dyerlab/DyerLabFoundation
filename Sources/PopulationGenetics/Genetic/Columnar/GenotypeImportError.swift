//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeImportError.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.06.28.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Errors thrown while importing a genotype table.
public enum GenotypeImportError: LocalizedError, Equatable {
    /// The input table had no rows.
    case emptyInput
    /// A required column was not found; the payload is the missing column's header.
    case missingColumn(String)
    /// A genotype cell could not be parsed. `locus` and `row` locate the offending
    /// cell; `value` is the raw text that failed to parse.
    case malformedGenotype(locus: String, row: Int, value: String)
    /// More than one row was marked as the maternal (adult) row for the same family.
    case duplicateMother(family: String)
    /// A side file's row/line count didn't match the primary file's row/column
    /// count (e.g. vcftools `--012`'s `.indv`/`.pos` companions).
    case sideFileMismatch(expected: Int, found: Int, file: String)
    /// A genotype dosage code fell outside the expected set (e.g. vcftools
    /// `--012`'s `{-1, 0, 1, 2}`). `row`/`column` are 0-based data positions.
    case invalidDosageCode(row: Int, column: Int, value: String)

    /// A user-presentable description of the failure.
    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            "The genotype table has no rows."
        case .missingColumn(let column):
            "The genotype table has no '\(column)' column."
        case .malformedGenotype(let locus, let row, let value):
            "Row \(row) has an unreadable genotype '\(value)' at locus \(locus)."
        case .duplicateMother(let family):
            "Family \(family) has more than one row marked as the mother."
        case .sideFileMismatch(let expected, let found, let file):
            "The \(file) file has \(found) entries but \(expected) were expected."
        case .invalidDosageCode(let row, let column, let value):
            "Row \(row + 1), column \(column + 1) has an invalid dosage code '\(value)'."
        }
    }
}
