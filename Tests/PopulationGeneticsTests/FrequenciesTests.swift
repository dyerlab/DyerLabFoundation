//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  FrequenciesTests.swift
//  PopulationGeneticsTests
//
//  Created by Rodney Dyer on 2025.06.02.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Testing
@testable import PopulationGenetics

@MainActor
struct FrequenciesTests {

    @Test func AlleleFrequencies() async throws {

        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let genotypes = dataStore.getGenotypesFor(locusName: "LTRS")
        #expect(genotypes.count == 363)

        let freqs = GenotypeFrequencies(genotypes: genotypes)

        #expect(freqs.alleles == ["01","02"])
        let p = freqs.frequency(for: "01")
        let q = freqs.frequency(for: "02")
        #expect(p.isFinite)
        #expect(p >= 0.0)
        #expect(p <= 1.0)
        #expect(p + q == 1)

        #expect(freqs.Ho == freqs.numHets / freqs.numGenos)

        #expect(abs((2*p*q) -  freqs.He) < 0.000000001)

        #expect(freqs.A == 2.0)

        #expect(freqs.Ae == (1.0 / (p*p + q*q)))

        #expect(freqs.N == 2.0 * 363.0)

        let pq = freqs.frequencies()
        #expect(pq == [p,q], "\(pq) != [\(p), \(q)]")
    }

    // MARK: - Incremental Addition Tests

    @Test func addGenotypeIncremental() async throws {
        let freqs = GenotypeFrequencies()
        #expect(freqs.N == 0)
        #expect(freqs.A == 0)

        let geno1 = Genotype(leftAllele: "A", rightAllele: "B")
        freqs.addGenotype(geno: geno1)

        #expect(freqs.N == 2.0)
        #expect(freqs.A == 2.0)
        #expect(freqs.numGenos == 1.0)
        #expect(freqs.numHets == 1.0)

        let geno2 = Genotype(leftAllele: "A", rightAllele: "A")
        freqs.addGenotype(geno: geno2)

        #expect(freqs.N == 4.0)
        #expect(freqs.numGenos == 2.0)
        #expect(freqs.numHets == 1.0) // Still only 1 het
    }

    @Test func addGenotypesArray() async throws {
        let freqs = GenotypeFrequencies()

        let geno1 = Genotype(leftAllele: "A", rightAllele: "B")
        let geno2 = Genotype(leftAllele: "A", rightAllele: "A")
        let geno3 = Genotype(leftAllele: "B", rightAllele: "B")

        freqs.addGenotypes(genos: [geno1, geno2, geno3])

        #expect(freqs.numGenos == 3.0)
        #expect(freqs.N == 6.0)
        #expect(freqs.A == 2.0)
    }

    @Test func addGenotypeWithHaploid() async throws {
        let freqs = GenotypeFrequencies()

        let haploid = Genotype(leftAllele: "A", rightAllele: "")
        freqs.addGenotype(geno: haploid)

        #expect(freqs.N == 1.0)
        #expect(freqs.numGenos == 1.0)
        #expect(freqs.numHets == 0.0)
    }

    // MARK: - Count Method Tests

    @Test func countForAllele() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let genotypes = dataStore.getGenotypesFor(locusName: "LTRS")
        let freqs = GenotypeFrequencies(genotypes: genotypes)

        let count1 = freqs.count(for: "01")
        let count2 = freqs.count(for: "02")

        #expect(count1 > 0)
        #expect(count2 > 0)
        #expect(Double(count1 + count2) == freqs.N)
    }

    // MARK: - A95 Tests

    @Test func a95WithCommonAlleles() async throws {
        // Create genotypes where all alleles are common (>= 5%)
        var genotypes = [Genotype]()
        for _ in 0..<50 {
            genotypes.append(Genotype(leftAllele: "A", rightAllele: "B"))
        }

        let freqs = GenotypeFrequencies(genotypes: genotypes)

        // Both A and B should be >= 5%, so A95 should equal A
        #expect(freqs.A95 == freqs.A)
        #expect(freqs.A95 == 2.0)
    }

    @Test func a95WithRareAlleles() async throws {
        // Create genotypes with one rare allele
        var genotypes = [Genotype]()
        for _ in 0..<98 {
            genotypes.append(Genotype(leftAllele: "A", rightAllele: "A"))
        }
        // Add 2 genotypes with rare allele (2/100 = 2%, less than 5%)
        genotypes.append(Genotype(leftAllele: "A", rightAllele: "B"))

        let freqs = GenotypeFrequencies(genotypes: genotypes)

        #expect(freqs.A == 2.0) // A and B alleles
        #expect(freqs.A95 == 1.0) // Only A is >= 5%
    }

    @Test func a95WithMultipleAlleles() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        // MP20 has multiple alleles
        let genotypes = dataStore.getGenotypesFor(locusName: "MP20")
        let freqs = GenotypeFrequencies(genotypes: genotypes)

        #expect(freqs.A95 <= freqs.A)
        #expect(freqs.A95 > 0)
    }

    // MARK: - HTML Export Test

    @Test func hTMLTableRowGeneration() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let genotypes = dataStore.getGenotypesFor(locusName: "LTRS")
        let freqs = GenotypeFrequencies(genotypes: genotypes)

        let html = freqs.asHTMLTableRow()

        #expect(html.contains("<tr>"))
        #expect(html.contains("</tr>"))
        #expect(html.contains("<td>"))
        #expect(html.contains("</td>"))
    }

    @Test func hTMLTableRowWithSpecificAlleles() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let genotypes = dataStore.getGenotypesFor(locusName: "LTRS")
        let freqs = GenotypeFrequencies(genotypes: genotypes)

        let html = freqs.asHTMLTableRow(alleles: ["1"])

        #expect(html.contains("<tr>"))
        #expect(html.contains("</tr>"))

        // Should only have one <td> for allele "1"
        let tdCount = html.components(separatedBy: "<td>").count - 1
        #expect(tdCount == 1)
    }

    // MARK: - Default Frequencies Test

    @Test func defaultFrequencies() async throws {
        let freqs = GenotypeFrequencies.defaultFrequencies

        #expect(freqs.counts["A"] == 25.0)
        #expect(freqs.counts["B"] == 75.0)
        #expect(freqs.numHets == 37.0)
        #expect(freqs.numGenos == 100.0)
    }

    // MARK: - Description Test

    @Test func frequenciesDescription() async throws {
        let dataStore = PopulationGeneticsPreviewData.shared.dataStore

        let genotypes = dataStore.getGenotypesFor(locusName: "LTRS")
        let freqs = GenotypeFrequencies(genotypes: genotypes)

        let description = freqs.description

        #expect(description.contains("Genotype Frequencies"))
        #expect(!description.isEmpty)
    }

    // MARK: - Empty Frequencies Tests

    @Test func emptyFrequencies() async throws {
        let freqs = GenotypeFrequencies()

        #expect(freqs.N == 0)
        #expect(freqs.A == 0)
        #expect(freqs.Ae == 0)
        #expect(freqs.A95 == 0)
        #expect(freqs.Ho.isNaN)
        #expect(freqs.He == 1.0) // Empty frequencies: 1.0 - 0.0 = 1.0
        #expect(freqs.alleles.isEmpty)
    }

}
