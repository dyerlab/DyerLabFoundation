//
//  BORICETests.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/23/26.
//

import XCTest
@testable import PopulationGenetics

final class BORICETests: XCTestCase {

    func testBORICERun() {
        // Create a dummy matrix and design
        let loci = [
            Locus(name: "L1"),
            Locus(name: "L2")
        ]
        
        let individuals = [
            Individual(name: "F1_O1"),
            Individual(name: "F1_O2"),
            Individual(name: "F2_O1")
        ]
        
        var cb1 = AlleleCodebook()
        cb1.register("100")
        cb1.register("102")
        
        var cb2 = AlleleCodebook()
        cb2.register("200")
        cb2.register("202")
        
        let col1 = MultiallelicColumn(codebook: cb1, left: [1, 1, 2], right: [1, 2, 2])
        let col2 = MultiallelicColumn(codebook: cb2, left: [1, 2, 1], right: [1, 2, 2])
        
        let matrix = GenotypeMatrix(individuals: individuals, loci: loci, columns: [col1, col2])
        
        let fam1 = MaternalFamily(id: "F1", mother: nil, offspring: [0, 1])
        let fam2 = MaternalFamily(id: "F2", mother: nil, offspring: [2])
        let design = ParentageDesign(families: [fam1, fam2])
        
        var params = BORICE.Parameters()
        params.numSteps = 100
        params.burnIn = 10
        params.thinning = 1
        
        let result = matrix.runBORICE(design: design, parameters: params)
        
        XCTAssertEqual(result.samples.count, 90)
        XCTAssert(result.meanT >= 0.0 && result.meanT <= 1.0)
        XCTAssert(result.meanF >= 0.0 && result.meanF <= 1.0)
    }
}
