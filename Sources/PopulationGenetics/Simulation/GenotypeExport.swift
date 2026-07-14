//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//
//  Created by Rodney Dyer on 4/23/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Foundation

// MARK: - Genotype Export

/// Exports genotype data for a set of individuals to a CSV string, looking up population
/// membership through the store's stratum records.
///
/// Column layout:
/// ```
/// Population, Individual, <LocusName1>, <LocusName2>, ...
/// ```
///
/// Each genotype cell is formatted as `"leftAllele:rightAllele"` (e.g. `"01:02"`),
/// matching the gstudio / R convention so downstream `read.csv()` calls require no
/// adaptation.  Missing or empty genotypes are written as `":"`.
///
/// **Stratum currency:** This overload reads population names from the store's stratum
/// records at `populationLevel`.  Make sure strata are updated after any migration step
/// before calling this function; see also the `populations:` overload which derives
/// population names directly from the dictionary keys.
///
/// - Parameters:
///   - individuals: Individuals to export (any order).
///   - locusNames: Ordered list of locus names; determines column order.
///   - store: Data store used to look up genotypes and strata.
///   - populationLevel: Stratum level used to assign the Population column (default: `"Population"`).
/// - Returns: CSV string including a header row.
public func exportGenotypesCSV(
    individuals: [Individual],
    locusNames: [String],
    store: PopGenStore,
    populationLevel: String = "Population"
) -> String {

    var lines: [String] = []
    lines.reserveCapacity(individuals.count + 1)
    lines.append((["Population", "Individual"] + locusNames).joined(separator: ","))

    for individual in individuals {
        let strata    = store.getStrata(for: individual)
        let popName   = strata.first(where: { $0.level == populationLevel })?.name ?? ""
        var cells     = [popName, individual.name]

        for locusName in locusNames {
            if let geno = store.getGenotype(for: individual, locusName: locusName) {
                cells.append(geno.isEmpty ? ":" : "\(geno.leftAllele):\(geno.rightAllele)")
            } else {
                cells.append(":")
            }
        }

        lines.append(cells.joined(separator: ","))
    }

    return lines.joined(separator: "\n")
}


/// Exports genotype data using a `populations` dictionary to determine population membership.
///
/// This overload is preferred during simulation snapshots because it reflects the live
/// population assignment (after migration) without requiring stratum records to be kept
/// current in the store.
///
/// Column layout and cell format are identical to the `individuals:` overload.
///
/// - Parameters:
///   - populations: Dictionary of population name → `[Individual]`; the key becomes
///     the value in the Population column for every individual in that array.
///   - locusNames: Ordered list of locus names; determines column order.
///   - store: Data store used to look up genotypes.
/// - Returns: CSV string including a header row, with rows grouped by population name (sorted).
public func exportGenotypesCSV(
    populations: [String: [Individual]],
    locusNames: [String],
    store: PopGenStore
) -> String {

    var lines: [String] = []
    lines.append((["Population", "Individual"] + locusNames).joined(separator: ","))

    for popName in populations.keys.naturalSorted() {
        guard let individuals = populations[popName] else { continue }
        for individual in individuals {
            var cells = [popName, individual.name]
            for locusName in locusNames {
                if let geno = store.getGenotype(for: individual, locusName: locusName) {
                    cells.append(geno.isEmpty ? ":" : "\(geno.leftAllele):\(geno.rightAllele)")
                } else {
                    cells.append(":")
                }
            }
            lines.append(cells.joined(separator: ","))
        }
    }

    return lines.joined(separator: "\n")
}
