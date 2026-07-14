//
//  GenotypeImportTests.swift
//  PopulationGenetics
//
//  Tests for importing a tabular microsatellite dataset (momID / OffspringID +
//  colon-delimited allele columns) into a GenotypeMatrix + ParentageDesign.
//

import Testing
@testable import PopulationGenetics

struct GenotypeImportTests {

    // Two families. mother rows have OffspringID 0.
    // Family A: mom 128:128 ; two offspring 128:130, 128:132
    // Family B: mom 130:130 ; one offspring 130:132
    private let csv = """
    momID,OffspringID,lat,lon,MP20,LTRS
    A,0,40.1,-77.2,128:128,01:01
    A,1,40.1,-77.2,128:130,01:02
    A,2,40.1,-77.2,128:132,01:01
    B,0,41.0,-78.0,130:130,02:02
    B,1,41.0,-78.0,130:132,02:01
    """

    private func imported() throws -> ImportedDataset {
        try importMicrosatTable(
            csv: csv,
            layout: GenotypeImportLayout(latitudeColumn: "lat", longitudeColumn: "lon")
        )
    }

    @Test func parsesShapeAndLoci() async throws {
        let ds = try imported()
        #expect(ds.matrix.individualCount == 5)
        #expect(ds.matrix.locusCount == 2)
        #expect(ds.matrix.locusIndex(named: "MP20") == 0)
        #expect(ds.matrix.locusIndex(named: "LTRS") == 1)
        // metadata columns must NOT be treated as loci
        #expect(ds.matrix.locusIndex(named: "momID") == nil)
        #expect(ds.matrix.locusIndex(named: "lat") == nil)
    }

    @Test func buildsParentageFromOffspringID() async throws {
        let ds = try imported()
        #expect(ds.parentage.families.count == 2)
        let a = try #require(ds.parentage.family(id: "A"))
        #expect(a.mother == 0)
        #expect(a.offspring == [1, 2])
        let b = try #require(ds.parentage.family(id: "B"))
        #expect(b.mother == 3)
        #expect(b.offspring == [4])
        #expect(ds.parentage.adultOrdinals == [0, 3])
        #expect(ds.parentage.offspringOrdinals == [1, 2, 4])
    }

    @Test func parsesCoordinates() async throws {
        let ds = try imported()
        #expect(ds.matrix.individuals[0].latitude == 40.1)
        #expect(ds.matrix.individuals[3].longitude == -78.0)
    }

    @Test func allelesRegisteredPerLocus() async throws {
        let ds = try imported()
        // MP20 alleles encountered: 128,130,132  → 3 non-null
        let mp20 = ds.matrix.column(named: "MP20")!
        #expect(mp20.codebook.alleleCount == 3)
        #expect(mp20.codebook.index(of: "128") != nil)
        // LTRS alleles: 01,02 → 2 non-null
        #expect(ds.matrix.column(named: "LTRS")!.codebook.alleleCount == 2)
    }

    @Test func endToEndPollenPool() async throws {
        // The whole point: import → pollen pool with maternal subtraction.
        let ds = try imported()
        let famA = try #require(ds.parentage.family(id: "A"))
        let mp20Index = try #require(ds.matrix.locusIndex(named: "MP20"))
        // mother 128:128; offspring 128:130 -> paternal 130, 128:132 -> paternal 132
        let pool = ds.matrix.pollenPool(forFamily: famA, atLocus: mp20Index)
        #expect(pool.nResolved == 2.0)
        #expect(pool.N == 2.0)
        let i130 = try #require(ds.matrix.column(named: "MP20")!.codebook.index(of: "130"))
        let i132 = try #require(ds.matrix.column(named: "MP20")!.codebook.index(of: "132"))
        #expect(pool.count(forIndex: i130) == 1.0)
        #expect(pool.count(forIndex: i132) == 1.0)
    }

    @Test func adultFrequenciesAfterImport() async throws {
        let ds = try imported()
        // Adults at MP20: A mom 128:128, B mom 130:130 → 128:2, 130:2
        let f = ds.matrix.adultFrequencies(atLocus: 0, design: ds.parentage)
        let i128 = try #require(ds.matrix.column(named: "MP20")!.codebook.index(of: "128"))
        let i130 = try #require(ds.matrix.column(named: "MP20")!.codebook.index(of: "130"))
        #expect(f.N == 4.0)
        #expect(f.count(forIndex: i128) == 2.0)
        #expect(f.count(forIndex: i130) == 2.0)
    }

    @Test func missingColumnThrows() async throws {
        #expect(throws: GenotypeImportError.missingColumn("momID")) {
            try importMicrosatTable(csv: "X,Y\n1,2", layout: GenotypeImportLayout())
        }
    }

    @Test func duplicateMotherThrows() async throws {
        let bad = """
        momID,OffspringID,MP20
        A,0,128:128
        A,0,130:130
        """
        #expect(throws: GenotypeImportError.duplicateMother(family: "A")) {
            try importMicrosatTable(csv: bad, layout: GenotypeImportLayout())
        }
    }
}
