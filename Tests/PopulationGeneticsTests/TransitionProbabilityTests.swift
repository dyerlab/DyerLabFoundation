//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  TransitionProbabilityTests.swift
//  PopulationGeneticsTests
//
//  TransitionProbability against gstudio's transition_probability() (1.15.3)
//  on the cornus families: compatibility, one parent with a random mate, and
//  two parents, per locus and multilocus (Fixtures/generate_transition_fixtures.R).
//
//  Created by Rodney Dyer on 2026.11.16.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation
import Testing
@testable import PopulationGenetics

struct TransitionProbabilityTests {

    struct Row: Decodable {
        let family: String
        let father: String
        let compatibility: [String: Double?]
        let randomMate: [String: Double?]
        let twoParent: [String: Double?]
        let compatibilityMultilocus: Double
        let randomMateMultilocus: Double
        let twoParentMultilocus: Double
    }

    struct Fixtures: Decodable {
        let loci: [String]
        let offspring: [Row]
    }

    private func close(_ a: Double?, _ b: Double??) -> Bool {
        switch (a, b ?? nil) {
        case (nil, nil): true
        case let (a?, b?): abs(a - b) <= 1e-12 * max(1, abs(b))
        default: false
        }
    }

    @Test func matchesGstudio() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/transition_fixtures.json")
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
        let dataset = try ExampleDataset.cornusFamilies.load()
        let matrix = dataset.matrix
        let families = Dictionary(uniqueKeysWithValues: dataset.parentage.families.map { ($0.id, $0) })
        let frequencies = matrix.loci.indices.map { [0] + matrix.frequencies(atLocus: $0).frequencies() }
        #expect(matrix.loci.map(\.name) == fixtures.loci)

        var position: [String: Int] = [:]
        for r in fixtures.offspring {
            let family = try #require(families[r.family])
            let k = position[r.family, default: 0]
            position[r.family] = k + 1
            let child = family.offspring[k]
            let mother = try #require(family.mother)
            let father = try #require(families[r.father]?.mother)

            for (j, name) in fixtures.loci.enumerated() {
                let column = matrix.columns[j]
                let o = column.alleles(at: child) ?? (0, 0), m = column.alleles(at: mother) ?? (0, 0)
                let d = column.alleles(at: father) ?? (0, 0)
                let context = "\(r.family)[\(k)] \(name)"
                #expect(close(TransitionProbability.compatibility(offspring: o, mother: m), r.compatibility[name]),
                        "\(context) compatibility")
                #expect(close(TransitionProbability.randomMate(offspring: o, mother: m, frequencies: frequencies[j]),
                              r.randomMate[name]), "\(context) random mate")
                #expect(close(TransitionProbability.twoParent(offspring: o, mother: m, father: d), r.twoParent[name]),
                        "\(context) two parents")
            }
            #expect(close(TransitionProbability.multilocus(matrix: matrix, offspring: child, mother: mother),
                          r.compatibilityMultilocus))
            #expect(close(TransitionProbability.multilocus(matrix: matrix, offspring: child, mother: mother,
                                                           frequencies: frequencies), r.randomMateMultilocus))
            #expect(close(TransitionProbability.multilocus(matrix: matrix, offspring: child, mother: mother,
                                                           father: father), r.twoParentMultilocus))
        }
        #expect(position.values.reduce(0, +) == fixtures.offspring.count)
    }

    @Test func paternityIndexIsTheRatioOfTwoParentToRandomMate() throws {
        // Mother A1A2 (1, 2), offspring A1A3: the father must give A3. A candidate A3A3 gives ½; a random mate
        // gives ½ p(A3), so the paternity index is 1 / p(A3).
        let p = [0, 0.5, 0.3, 0.2]
        let two = try #require(TransitionProbability.twoParent(offspring: (1, 3), mother: (1, 2), father: (3, 3)))
        let random = try #require(TransitionProbability.randomMate(offspring: (1, 3), mother: (1, 2), frequencies: p))
        #expect(two == 0.5)
        #expect(abs(two / random - 1 / 0.2) < 1e-12)
        #expect(TransitionProbability.compatibility(offspring: (1, 3), mother: (0, 2)) == nil)
    }
}
