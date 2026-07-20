//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  ExampleDataset.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/14/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//
//  Bundled example datasets (see `ExampleData/` resources, wired via
//  `Package.swift`), imported through the same public import functions a real
//  user import would use — bundling these can never drift from the real
//  import path. Lets downstream apps (previews, "New Document" templates,
//  onboarding) draw on real data without shipping their own copy.

import Foundation

/// A genetic dataset bundled with this package for demonstration and testing.
public enum ExampleDataset: String, CaseIterable, Sendable {

    /// *Araptus attenuatus* (bark beetle) population sample: 363 individuals,
    /// 8 microsatellite loci, a 3-level stratum hierarchy (Species/Cluster/Population),
    /// and spatial coordinates. No parentage.
    case arapatPopulations

    /// *Cornus florida* (dogwood) maternal family sample: 62 individuals across
    /// 22 families, 5 microsatellite loci — for pollen-pool / parentage analysis.
    case cornusFamilies

    /// A `vcftools --012` SNP panel: 1318 individuals x 926 biallelic loci. No
    /// allele identity — every locus carries a REF/ALT-placeholder codebook only.
    case phylogSNPPanel

    /// A short human-readable label, for use in dataset pickers.
    public var displayName: String {
        switch self {
        case .arapatPopulations: return "Araptus attenuatus Populations"
        case .cornusFamilies: return "Cornus florida Families"
        case .phylogSNPPanel: return "Phylogeography SNP Panel"
        }
    }

    /// The Latin binomial this dataset was sampled from, or `nil` when the
    /// dataset spans an anonymized panel with no single associated species.
    public var species: String? {
        switch self {
        case .arapatPopulations: return "Araptus attenuatus"
        case .cornusFamilies: return "Cornus florida"
        case .phylogSNPPanel: return nil
        }
    }

    /// A couple of sentences describing the dataset's origin and intended
    /// use, suitable as the default `description` metadata when this
    /// dataset is saved to a `GenotypeMatrixStore` file.
    public var description: String {
        switch self {
        case .arapatPopulations:
            return """
                A range-wide sample of the cactus-associated bark beetle Araptus attenuatus across the Baja \
                California peninsula and Sonoran Desert, genotyped at 8 microsatellite loci. Individuals are \
                organized into a three-level Species/Cluster/Population hierarchy with georeferenced \
                coordinates, making it well suited for spatial and hierarchical population-structure analyses.
                """
        case .cornusFamilies:
            return """
                A maternal-family sample of flowering dogwood (Cornus florida), consisting of 62 individuals \
                across 22 open-pollinated families genotyped at 5 microsatellite loci. Designed for \
                pollen-pool and parentage analyses, where offspring are grouped under known mothers to \
                reconstruct mating patterns.
                """
        case .phylogSNPPanel:
            return """
                A large biallelic SNP dataset of 1,318 individuals genotyped at 926 loci, imported from \
                vcftools --012 dosage output. Allele identity isn't preserved (each locus uses a REF/ALT \
                placeholder codebook), so it's best suited for dosage-based analyses like distance and \
                structure rather than allele-frequency work requiring true allele labels.
                """
        }
    }

    /// Imports this dataset and saves it to `url`, tagged with this
    /// dataset's canonical `displayName`/`species`/`description` metadata —
    /// the same metadata a "New Document" template or onboarding flow would
    /// want without re-typing it at each call site.
    public func save(to url: URL) async throws {
        let dataset = try load()
        try await GenotypeMatrixStore.save(dataset.matrix, parentage: dataset.parentage, strata: dataset.strata,
                                            projectName: displayName, species: species, description: description,
                                            to: url)
    }

    /// Imports this dataset through the real import path.
    public func load() throws -> ImportedDataset {
        switch self {
        case .arapatPopulations:
            return try importPopulationTable(
                csv: try ExampleData.text("arapat", extension: "csv"),
                layout: .init(strataColumns: ["Species", "Cluster", "Population"],
                              nameColumn: "ID", latitudeColumn: "Latitude", longitudeColumn: "Longitude"))

        case .cornusFamilies:
            return try importMicrosatTable(
                csv: try ExampleData.text("cornus", extension: "csv"),
                layout: GenotypeImportLayout(familyColumn: "ID", offspringColumn: "OffID",
                                             latitudeColumn: "Latitude", longitudeColumn: "Longitude"))

        case .phylogSNPPanel:
            return try importVCFTools012(
                dosageText: try ExampleData.text("phylog", extension: "012"),
                indvText: try ExampleData.text("phylog.012", extension: "indv"),
                posText: try ExampleData.text("phylog.012", extension: "pos"))
        }
    }
}

/// Raw-text access to the bundled example-data files themselves, for callers
/// pinned to exact file content (e.g. regression tests).
public enum ExampleData {

    public enum LoadError: LocalizedError {
        case resourceMissing(String)

        public var errorDescription: String? {
            switch self {
            case .resourceMissing(let name):
                return "Bundled example-data resource '\(name)' could not be found."
            }
        }
    }

    /// Reads a bundled `ExampleData/` resource file as UTF-8 text.
    ///
    /// - Parameters:
    ///   - name: File name without its extension (e.g. `"phylog.012"` for `phylog.012.indv`).
    ///   - ext: File extension without the leading dot (e.g. `"indv"`).
    public static func text(_ name: String, extension ext: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "ExampleData") else {
            throw LoadError.resourceMissing("\(name).\(ext)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
