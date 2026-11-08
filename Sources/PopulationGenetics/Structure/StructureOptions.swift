//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StructureOptions.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// The choices a dataset offers a structure analysis: its loci and the stratum levels its sample can be grouped by.
public struct StructureOptions: Sendable, Equatable {

    /// Whose genotypes are analysed.
    public let sample: StructureSpec.Sample
    /// Every locus name, in matrix order.
    public let loci: [String]
    /// The stratum levels, outermost first. Paternal gametes always offer ``StructureSpec/familyLevel`` first.
    public let levels: [String]
    /// The alleles seen at each locus, in matrix order, among the individuals whose genotypes are analysed
    /// (the adults, or the offspring and their mothers).
    public let alleleCounts: [Int]

    /// Reads the choices from a dataset.
    ///
    /// - Parameters:
    ///   - dataset: The genotypes.
    ///   - sample: Whose genotypes are analysed.
    public init(dataset: ImportedDataset, sample: StructureSpec.Sample) {
        self.sample = sample
        loci = dataset.matrix.loci.map(\.name)
        var levels: [String] = sample == .paternalGametes ? [StructureSpec.familyLevel] : []
        let ordinals = sample == .adults ? dataset.adultOrdinals : dataset.familiesWithOffspring.flatMap(\.offspring)
        let mothers = Self.mothers(in: dataset)
        for ordinal in ordinals {
            for reference in Self.references(of: ordinal, in: dataset, mothers: mothers)
            where !levels.contains(reference.level) {
                levels.append(reference.level)
            }
        }
        self.levels = levels
        let genotyped = sample == .adults ? dataset.adultOrdinals
            : dataset.familiesWithOffspring.flatMap { family in family.offspring + (family.mother.map { [$0] } ?? []) }
        alleleCounts = dataset.matrix.columns.map { column in
            var seen = Set<UInt8>()
            for ordinal in genotyped {
                guard let (a, b) = column.alleles(at: ordinal) else { continue }
                if a != 0 { seen.insert(a) }
                if b != 0 { seen.insert(b) }
            }
            return seen.count
        }
    }

    /// The statistics a spec's table will flag from allele counts alone, before anything is estimated; Hs is
    /// checked once the table is.
    ///
    /// - Parameter spec: The spec.
    /// - Returns: A remark such as `"Gst may understate differentiation at AML (13 alleles)."`, or `nil`.
    public func concerns(for spec: StructureSpec) -> String? {
        guard spec.table == .perLocus, sample == .adults else { return nil }
        let thresholds = spec.thresholds
        let indices = spec.locus.flatMap { locus in loci.firstIndex(of: locus).map { [$0] } } ?? Array(loci.indices)
        func listed(_ concern: (Int) -> Bool) -> String {
            indices.filter { concern(alleleCounts[$0]) }.map { "\(loci[$0]) (\(alleleCounts[$0]))" }
                .joined(separator: ", ")
        }
        var remarks: [String] = []
        if spec.columns.contains(.gst) {
            let many = listed { $0 >= thresholds.gstAlleles }
            if !many.isEmpty { remarks.append("Gst may understate differentiation with many alleles: \(many).") }
        }
        if spec.columns.contains(.dest) {
            let few = listed { $0 <= thresholds.destAlleles }
            if !few.isEmpty { remarks.append("Dest may be unstable with few alleles: \(few).") }
        }
        return remarks.isEmpty ? nil : remarks.joined(separator: " ")
    }

    /// The level to start with: families for gametes, otherwise the innermost level, which is the population.
    public var defaultLevel: String? { sample == .paternalGametes ? levels.first : levels.last }

    /// Whether there is more than one level to choose from.
    public var hasLevelChoice: Bool { levels.count > 1 }

    /// The spec to start with, or `nil` if the dataset has nothing to group by.
    public var defaultSpec: StructureSpec? {
        defaultLevel.map { StructureSpec(sample: sample, level: $0) }
    }

    /// A spec adjusted to this dataset: a missing locus becomes every locus, and a missing level the default.
    ///
    /// - Parameter spec: The spec to check.
    /// - Returns: The adjusted spec, or `nil` if there is no level at all.
    public func validated(_ spec: StructureSpec) -> StructureSpec? {
        guard let fallback = defaultLevel else { return nil }
        var spec = spec
        spec.sample = sample
        if !StructureSpec.Statistic.choices(for: sample).contains(spec.statistic) {
            spec.statistic = StructureSpec.Statistic.choices(for: sample)[0]
        }
        let columns = StructureSpec.Column.choices(for: sample)
        spec.columns = spec.columns.filter(columns.contains)
        if spec.columns.isEmpty { spec.columns = StructureSpec.Column.defaults(for: sample) }
        if let locus = spec.locus, !loci.contains(locus) { spec.locus = nil }
        if !levels.contains(spec.level) { spec.level = fallback }
        return spec
    }

    /// An individual's strata, with an offspring's mother's strata after its own.
    ///
    /// - Parameters:
    ///   - ordinal: The individual's row.
    ///   - dataset: The genotypes.
    ///   - mothers: Each offspring's mother, from ``mothers(in:)``.
    /// - Returns: The strata, outermost first.
    static func references(of ordinal: Int, in dataset: ImportedDataset,
                           mothers: [Int: Int]) -> [StratumReference] {
        let own = dataset.strata[dataset.matrix.individuals[ordinal].id] ?? []
        guard let mother = mothers[ordinal] else { return own }
        let maternal = dataset.strata[dataset.matrix.individuals[mother].id] ?? []
        return own + maternal.filter { reference in !own.contains { $0.level == reference.level } }
    }

    /// Each offspring's mother.
    ///
    /// - Parameter dataset: The genotypes.
    /// - Returns: The mother's row, keyed by the offspring's row.
    static func mothers(in dataset: ImportedDataset) -> [Int: Int] {
        var mothers: [Int: Int] = [:]
        for family in dataset.parentage.families {
            guard let mother = family.mother else { continue }
            for child in family.offspring { mothers[child] = mother }
        }
        return mothers
    }
}
