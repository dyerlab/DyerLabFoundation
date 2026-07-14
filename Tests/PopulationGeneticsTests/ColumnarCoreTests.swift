//
//  ColumnarCoreTests.swift
//  PopulationGenetics
//
//  Tests for the columnar genetic core: AlleleCodebook, AlleleFrequencies,
//  BiallelicColumn, MultiallelicColumn, and GenotypeColumn reductions.
//

import Testing
@testable import PopulationGenetics

struct ColumnarCoreTests {

    // MARK: - AlleleCodebook

    @Test func codebookReservesNullAtZero() async throws {
        let book = AlleleCodebook(alleles: ["G", "A"])
        #expect(book.label(for: 0) == "")
        #expect(book.alleleCount == 2)
        #expect(book.count == 3)
        #expect(book.index(of: "G") == 1)
        #expect(book.index(of: "A") == 2)
        #expect(book.index(of: "") == AlleleCodebook.nullIndex)
        #expect(book.alleleIndices == [1, 2])
    }

    @Test func codebookRegisterDeduplicates() async throws {
        var book = AlleleCodebook()
        let i1 = book.register("146")
        let i2 = book.register("150")
        let i1again = book.register("146")
        #expect(i1 == 1)
        #expect(i2 == 2)
        #expect(i1again == i1)
        #expect(book.register("") == AlleleCodebook.nullIndex)
        #expect(book.alleleCount == 2)
    }

    @Test func codebookLabelRoundTrip() async throws {
        let book = AlleleCodebook(alleles: ["142", "146", "150"])
        for idx in book.alleleIndices {
            let label = book.label(for: idx)
            #expect(book.index(of: label) == idx)
        }
    }

    // MARK: - AlleleFrequencies math

    @Test func frequenciesKnownData() async throws {
        // Codebook A=1, B=2. Add AB, AA, BB -> N=6, p=q=0.5.
        let book = AlleleCodebook(alleles: ["A", "B"])
        var freqs = AlleleFrequencies(codebook: book)
        freqs.add(left: 1, right: 2)   // AB (het)
        freqs.add(left: 1, right: 1)   // AA
        freqs.add(left: 2, right: 2)   // BB

        #expect(freqs.N == 6.0)
        #expect(freqs.numGenos == 3.0)
        #expect(freqs.numHets == 1.0)
        #expect(freqs.count(forIndex: 1) == 3.0)
        #expect(freqs.count(forIndex: 2) == 3.0)

        let p = freqs.frequency(forIndex: 1)
        let q = freqs.frequency(forIndex: 2)
        #expect(p == 0.5)
        #expect(q == 0.5)
        #expect(freqs.A == 2.0)
        #expect(abs(freqs.He - 0.5) < 1e-12)
        #expect(abs(freqs.Ae - 2.0) < 1e-12)
        #expect(abs(freqs.Ho - (1.0 / 3.0)) < 1e-12)
        #expect(freqs.frequencies() == [0.5, 0.5])
    }

    @Test func frequenciesHaploidCountsOneAllele() async throws {
        let book = AlleleCodebook(alleles: ["A", "B"])
        var freqs = AlleleFrequencies(codebook: book)
        freqs.add(left: 1, right: 0)   // haploid A
        #expect(freqs.N == 1.0)
        #expect(freqs.numGenos == 1.0)
        #expect(freqs.numHets == 0.0)
    }

    @Test func frequenciesAddRemoveIsSymmetric() async throws {
        // Permutation invariant: add a batch, remove it, return to baseline.
        let book = AlleleCodebook(alleles: ["A", "B", "C"])
        var freqs = AlleleFrequencies(codebook: book)
        let batch: [(UInt8, UInt8)] = [(1, 2), (2, 3), (1, 1), (3, 3), (1, 3)]
        for g in batch { freqs.add(left: g.0, right: g.1) }
        for g in batch { freqs.remove(left: g.0, right: g.1) }

        #expect(freqs.N == 0.0)
        #expect(freqs.numGenos == 0.0)
        #expect(freqs.numHets == 0.0)
        #expect(freqs.counts.allSatisfy { $0 == 0.0 })
    }

    @Test func frequenciesEmptyMatchesConventions() async throws {
        let book = AlleleCodebook(alleles: ["A", "B"])
        let freqs = AlleleFrequencies(codebook: book)
        #expect(freqs.N == 0.0)
        #expect(freqs.A == 0.0)
        #expect(freqs.Ae == 0.0)
        #expect(freqs.A95 == 0.0)
        #expect(freqs.Ho.isNaN)
        #expect(freqs.He == 1.0)               // 1 - 0
        #expect(freqs.frequencies().isEmpty)
        #expect(freqs.frequency(forIndex: 1).isNaN)
    }

    @Test func a95FiltersRareAlleles() async throws {
        // 49 AA + 1 AB -> A allele 99/100, B 1/100 (< 5%).
        let book = AlleleCodebook(alleles: ["A", "B"])
        var freqs = AlleleFrequencies(codebook: book)
        for _ in 0..<49 { freqs.add(left: 1, right: 1) }
        freqs.add(left: 1, right: 2)
        #expect(freqs.A == 2.0)
        #expect(freqs.A95 == 1.0)
    }

    // MARK: - BiallelicColumn

    @Test func biallelicPackingIsLSBFirst() async throws {
        let book = AlleleCodebook(alleles: ["G", "A"])
        // codes: 0->1(AA), 1->2(AB), 2->3(BB), 3->0(missing)
        let column = BiallelicColumn(codebook: book, codes: [1, 2, 3, 0])
        // byte0 = 0b00_11_10_01 = 0x39
        #expect(column.packedBytes[0] == 0x39)
        #expect(column.code(at: 0) == 1)
        #expect(column.code(at: 1) == 2)
        #expect(column.code(at: 2) == 3)
        #expect(column.code(at: 3) == 0)
    }

    @Test func biallelicZeroBufferIsAllMissing() async throws {
        let book = AlleleCodebook(alleles: ["G", "A"])
        let column = BiallelicColumn(codebook: book, count: 10)
        for i in 0..<column.count {
            #expect(column.isEmpty(at: i))
            #expect(column.alleles(at: i) == nil)
            #expect(column.dosage(at: i) == nil)
        }
    }

    @Test func biallelicAlleleAndDosageMapping() async throws {
        let book = AlleleCodebook(alleles: ["G", "A"])
        let column = BiallelicColumn(codebook: book, codes: [1, 2, 3, 0])
        #expect(column.alleles(at: 0)! == (1, 1))
        #expect(column.alleles(at: 1)! == (1, 2))
        #expect(column.alleles(at: 2)! == (2, 2))
        #expect(column.alleles(at: 3) == nil)
        #expect(column.dosage(at: 0) == 0)
        #expect(column.dosage(at: 1) == 1)
        #expect(column.dosage(at: 2) == 2)
        #expect(column.isHeterozygote(at: 1))
        #expect(!column.isHeterozygote(at: 0))
    }

    @Test func biallelicSetCodeRoundTripsAcrossBytes() async throws {
        let book = AlleleCodebook(alleles: ["G", "A"])
        var column = BiallelicColumn(codebook: book, count: 9)
        let pattern: [UInt8] = [1, 2, 3, 1, 2, 3, 0, 1, 2]
        for (i, c) in pattern.enumerated() { column.setCode(at: i, c) }
        for (i, c) in pattern.enumerated() { #expect(column.code(at: i) == c) }
    }

    @Test func biallelicColumnFrequencies() async throws {
        let book = AlleleCodebook(alleles: ["G", "A"])
        let column = BiallelicColumn(codebook: book, codes: [1, 2, 3]) // AA, AB, BB
        let freqs = column.frequencies()
        #expect(freqs.N == 6.0)
        #expect(freqs.count(forIndex: 1) == 3.0)
        #expect(freqs.count(forIndex: 2) == 3.0)
        #expect(freqs.numHets == 1.0)
        #expect(abs(freqs.He - 0.5) < 1e-12)
    }

    // MARK: - MultiallelicColumn

    @Test func multiallelicEmptyHaploidDiploid() async throws {
        let book = AlleleCodebook(alleles: ["142", "146", "150"]) // 1,2,3
        var column = MultiallelicColumn(codebook: book, capacity: 3)
        column.set(at: 0, left: 0, right: 0)   // empty
        column.set(at: 1, left: 3, right: 0)   // haploid
        column.set(at: 2, left: 3, right: 1)   // diploid (unsorted)

        #expect(column.isEmpty(at: 0))
        #expect(column.alleles(at: 0) == nil)

        #expect(!column.isEmpty(at: 1))
        #expect(column.alleles(at: 1)! == (0, 3))   // canonical sorted, 0 leads

        #expect(column.alleles(at: 2)! == (1, 3))   // sorted
        #expect(column.isHeterozygote(at: 2))
    }

    @Test func multiallelicFrequenciesOverSubset() async throws {
        let book = AlleleCodebook(alleles: ["A", "B", "C"]) // 1,2,3
        let column = MultiallelicColumn(
            codebook: book,
            left:  [1, 2, 1, 3],
            right: [1, 3, 2, 3]
        )
        // Reduce only individuals 0 and 2: (1,1) and (1,2)
        let subset = column.frequencies(over: [0, 2])
        #expect(subset.N == 4.0)
        #expect(subset.count(forIndex: 1) == 3.0)
        #expect(subset.count(forIndex: 2) == 1.0)
        #expect(subset.count(forIndex: 3) == 0.0)
        #expect(subset.numGenos == 2.0)
        #expect(subset.numHets == 1.0)
    }

    // MARK: - Markdown

    @Test func markdownTableShape() async throws {
        let book = AlleleCodebook(alleles: ["A", "B"])
        let column = BiallelicColumn(codebook: book, codes: [1, 2, 3])
        let freqs = column.frequencies()

        let row = freqs.asMarkdownTableRow(codebook: book)
        #expect(row.hasPrefix("|"))
        #expect(row.hasSuffix("|"))
        #expect(row.contains("0.5000"))

        let table = freqs.asMarkdownTable(codebook: book)
        let lines = table.split(separator: "\n")
        #expect(lines.count == 3)            // header, separator, data
        #expect(table.contains("---"))
        #expect(table.contains("| A | B |"))
    }
}
