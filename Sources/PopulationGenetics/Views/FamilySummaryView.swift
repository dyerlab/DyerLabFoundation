//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FamilySummaryView.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.01.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import SwiftUI

/// One maternal family at a glance: who and where it is, how its offspring's
/// paternal alleles resolve, and any offspring genotype its mother couldn't
/// have contributed to.
public struct FamilySummaryView: View {
    /// The genotypes.
    public let dataset: ImportedDataset
    /// The family's paternal-allele summary.
    public let report: FamilyReport

    /// Creates a family's summary.
    ///
    /// - Parameters:
    ///   - dataset: The genotypes.
    ///   - report: The family's paternal-allele summary.
    public init(dataset: ImportedDataset, report: FamilyReport) {
        self.dataset = dataset
        self.report = report
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        Text("Mother").foregroundStyle(.secondary)
                        Text(motherText)
                    }
                    GridRow {
                        Text("Offspring").foregroundStyle(.secondary)
                        Text(report.family.offspring.count, format: .number)
                    }
                    if report.family.mother != nil {
                        GridRow {
                            Text("Paternal alleles").foregroundStyle(.secondary)
                            Text("\(report.resolved) resolved · \(report.ambiguous) ambiguous · "
                                 + "\(report.missing) missing")
                        }
                    }
                }
                mismatches
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Family \(report.family.id)")
                .font(.title2.bold())
            if let place = placeText {
                Text(place)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var mismatches: some View {
        if report.family.mother == nil {
            Label("The mother wasn't genotyped, so paternal alleles can't be recovered.",
                  systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        } else if report.mismatches.isEmpty {
            Label("Every offspring shares an allele with its mother at every locus.", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                let noun = report.mismatches.count == 1 ? "genotype" : "genotypes"
                Label("\(report.mismatches.count) offspring \(noun) share no allele with the mother",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                ForEach(report.mismatches) { mismatch in
                    Text(mismatchText(mismatch))
                        .font(.callout.monospacedDigit())
                        .padding(.leading, 24)
                }
            }
        }
    }

    // MARK: - Text

    private var motherText: String {
        guard let mother = report.family.mother else { return "Not genotyped" }
        return dataset.matrix.individuals[mother].name
    }

    /// The family's population and coordinates, taken from its first member.
    private var placeText: String? {
        guard let first = report.family.mother ?? report.family.offspring.first else { return nil }
        let individual = dataset.matrix.individuals[first]
        var parts: [String] = []
        if dataset.hasPopulations { parts.append(dataset.populationName(at: first)) }
        if let latitude = individual.latitude, let longitude = individual.longitude {
            parts.append(String(format: "%.5f, %.5f", latitude, longitude))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func mismatchText(_ mismatch: FamilyReport.Mismatch) -> String {
        let name = dataset.matrix.individuals[mismatch.offspring].name
        let locus = dataset.matrix.loci[mismatch.locus].name
        let offspring = genotype(at: mismatch.offspring, locus: mismatch.locus)
        let mother = report.family.mother.map { genotype(at: $0, locus: mismatch.locus) } ?? ""
        return "\(name) at \(locus): \(offspring) (mother \(mother))"
    }

    private func genotype(at ordinal: Int, locus: Int) -> String {
        dataset.alleleLabels(at: ordinal, locus: locus).map { $0 + ":" + $1 } ?? "missing"
    }
}

// MARK: - Previews

#Preview("Cornus family") {
    let dataset = try! ExampleDataset.cornusFamilies.load()
    let family = dataset.parentage.families.first { $0.mother != nil && !$0.offspring.isEmpty }!
    FamilySummaryView(dataset: dataset, report: FamilyReport(dataset: dataset, family: family))
        .frame(width: 600, height: 240)
}

#Preview("Mismatched offspring") {
    let csv = """
        Population,ID,Offspring,A,B
        North,F1,0,1:2,3:3
        North,F1,1,1:1,3:4
        North,F1,2,5:6,3:3
        """
    let dataset = try! GenotypeTableLayout(csv: csv).importTable(csv: csv)
    FamilySummaryView(dataset: dataset, report: FamilyReport(dataset: dataset, family: dataset.parentage.families[0]))
        .frame(width: 600, height: 240)
}
