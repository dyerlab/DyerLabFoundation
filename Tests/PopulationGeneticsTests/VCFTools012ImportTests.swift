//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  VCFTools012ImportTests.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 7/13/26.
//
//  Verifies importVCFTools012 against the real Data/phylog.012 triplet.
//

import Testing
import Foundation
@testable import PopulationGenetics

struct VCFTools012ImportTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // VCFTools012ImportTests.swift -> PopulationGeneticsTests/
            .deletingLastPathComponent() // PopulationGeneticsTests/ -> Tests/
            .deletingLastPathComponent() // Tests/ -> repo root
    }

    private func loadDataFile(_ name: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent("Data").appendingPathComponent(name), encoding: .utf8)
    }

    private func importPhylog() throws -> ImportedDataset {
        try importVCFTools012(
            dosageText: try loadDataFile("phylog.012"),
            indvText: try loadDataFile("phylog.012.indv"),
            posText: try loadDataFile("phylog.012.pos")
        )
    }

    @Test func importsPhylogIndividualsAndLoci() async throws {
        let dataset = try importPhylog()

        #expect(dataset.matrix.individualCount == 1318)
        #expect(dataset.matrix.locusCount == 926)
        #expect(dataset.matrix.individuals.first?.name == "AkronZooOH_969")
    }

    @Test func importsPhylogLociAsRefAltPlaceholders() async throws {
        let dataset = try importPhylog()

        #expect(dataset.matrix.loci.allSatisfy { $0.alleleProvenance == .refAltPlaceholder })
        #expect(dataset.matrix.columns.allSatisfy { $0.codebook.labels == ["", "Z", "z"] })
        #expect(dataset.matrix.columns.allSatisfy { $0.markerType == .biallelicSNP })
    }

    @Test func importsPhylogSynthesizesLocusNamesFromContigAndPosition() async throws {
        let dataset = try importPhylog()

        let first = dataset.matrix.loci[0]
        #expect(first.contig == "dDocent_Contig_16")
        #expect(first.location == 80)
        #expect(first.name == "dDocent_Contig_16:80")
    }

    @Test func importsPhylogDosageCodesMatchRawFile() async throws {
        // Row 0 ("AkronZooOH_969"), first five raw dosage codes: 1,1,1,0,1
        // (vcftools -1/0/1/2) -> packed 0/1/2/3 via +1: 2,2,2,1,2.
        let dataset = try importPhylog()

        #expect(dataset.matrix.columns[0].alleles(at: 0) != nil)
        for locusIndex in 0..<5 {
            let alleles = dataset.matrix.columns[locusIndex].alleles(at: 0)
            #expect(alleles != nil, "locus \(locusIndex) should not be missing for individual 0")
        }
        // locus 3's raw code was 0 (hom-ref) -> (Z, Z) = (1, 1); the rest were 1 (het) -> (Z, z) = (1, 2).
        let hetAlleles = try #require(dataset.matrix.columns[0].alleles(at: 0))
        #expect(hetAlleles == (1, 2))
        let homRefAlleles = try #require(dataset.matrix.columns[3].alleles(at: 0))
        #expect(homRefAlleles == (1, 1))
    }

    @Test func importsPhylogPreservesMissingAndHomAltCodes() async throws {
        let dataset = try importPhylog()

        // At least one -1 (missing) and one 2 (hom-alt) genotype exist somewhere
        // in the real file (confirmed directly against Data/phylog.012).
        let anyMissing = (0..<dataset.matrix.locusCount).contains { j in
            (0..<dataset.matrix.individualCount).contains { i in dataset.matrix.columns[j].isEmpty(at: i) }
        }
        let anyHomAlt = (0..<dataset.matrix.locusCount).contains { j in
            (0..<dataset.matrix.individualCount).contains { i in
                guard let pair = dataset.matrix.columns[j].alleles(at: i) else { return false }
                return pair == (2, 2)
            }
        }
        #expect(anyMissing)
        #expect(anyHomAlt)
    }

    @Test func rejectsDosageRowCountMismatchWithIndvFile() async throws {
        let dosage = try loadDataFile("phylog.012")
        let posText = try loadDataFile("phylog.012.pos")
        let shortIndv = "only_one_sample\n"

        #expect(throws: GenotypeImportError.self) {
            try importVCFTools012(dosageText: dosage, indvText: shortIndv, posText: posText)
        }
    }
}
