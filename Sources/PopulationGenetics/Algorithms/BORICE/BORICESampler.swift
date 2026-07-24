//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  BORICESampler.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 7/23/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

import Foundation

extension BORICE {

    public struct Parameters {
        public var numSteps: Int = 100_000
        public var burnIn: Int = 10_000
        public var thinning: Int = 10
        public var tTuning: Double = 0.05
        public var afTuning: Double = 0.1
        public var initialT: Double = 0.5

        public init() {}
    }

    public struct State {
        public var t: Double
        public var inbreedingHistories: [Int] // One per family
        public var yValues: [[Double]] // [locus][allele]
        public var alleleFrequencies: [[Double]] // [locus][allele]
        public var maternalGenotypes: [[(UInt8, UInt8)]] // [family][locus]
    }

    public class Sampler {
        let matrix: GenotypeMatrix
        let design: ParentageDesign
        let parameters: Parameters
        let hasNullModel: [Bool]

        private var imputedLoci: [[Int]] = [] // [family][locusIndices]
        private var observedImputedLoci: [[Int]] = [] // [family][locusIndices]

        public init(matrix: GenotypeMatrix, design: ParentageDesign, parameters: Parameters = Parameters(), hasNullModel: [Bool]? = nil) {
            self.matrix = matrix
            self.design = design
            self.parameters = parameters
            self.hasNullModel = hasNullModel ?? [Bool](repeating: false, count: matrix.locusCount)

            // Initialize state
            let initialT = parameters.initialT
            let initialIH = [Int](repeating: 0, count: design.families.count)

            var initialY = [[Double]]()
            var initialAF = [[Double]]()
            for j in 0..<matrix.locusCount {
                let codebook = matrix.columns[j].codebook
                let count = codebook.count
                initialY.append([Double](repeating: 1.0, count: count))
                initialAF.append([Double](repeating: 1.0 / Double(count), count: count))
            }

            var initialMoms = [[(UInt8, UInt8)]]()
            self.imputedLoci = [[Int]](repeating: [], count: design.families.count)
            self.observedImputedLoci = [[Int]](repeating: [], count: design.families.count)

            for (i, fam) in design.families.enumerated() {
                var momGenos = [(UInt8, UInt8)]()
                for j in 0..<matrix.locusCount {
                    let column = matrix.columns[j]
                    if let momIdx = fam.mother, !column.isEmpty(at: momIdx) {
                        let alleles = column.alleles(at: momIdx)!
                        momGenos.append(alleles)
                        
                        // If it's a homozygote and we have a null model, it's observed-imputed
                        if self.hasNullModel[j] && alleles.0 == alleles.1 {
                            self.observedImputedLoci[i].append(j)
                        }
                    } else {
                        // Missing or no maternal tissue: fully imputed
                        self.imputedLoci[i].append(j)
                        momGenos.append((1, 1)) // Start with first allele
                    }
                }
                initialMoms.append(momGenos)
            }

            self.currentState = State(
                t: initialT,
                inbreedingHistories: initialIH,
                yValues: initialY,
                alleleFrequencies: initialAF,
                maternalGenotypes: initialMoms
            )
        }

        // ... (Likelihood calculations and run loop)

        private func updateMoms(currentLnL: Double) -> Double {
            var totalLnL = currentLnL
            
            for i in 0..<design.families.count {
                let imputed = imputedLoci[i]
                let obsImp = observedImputedLoci[i]
                let totalImpCount = imputed.count + obsImp.count
                guard totalImpCount > 0 else { continue }

                // Pick one imputed locus randomly
                let randIdx = Int.random(in: 0..<totalImpCount, using: &rng)
                let locusIdx: Int
                let isObservedImputed: Bool
                if randIdx < imputed.count {
                    locusIdx = imputed[randIdx]
                    isObservedImputed = false
                } else {
                    locusIdx = obsImp[randIdx - imputed.count]
                    isObservedImputed = true
                }

                let prevGenotype = currentState.maternalGenotypes[i][locusIdx]
                let prevFamilyLnL = calculateFamilyLogLikelihood(familyIndex: i, state: currentState)
                
                let F = inbreedingCoefficient(forIH: currentState.inbreedingHistories[i])
                let af = currentState.alleleFrequencies[locusIdx]
                let numAlleles = af.count

                var nextGenotype: (UInt8, UInt8)
                if isObservedImputed {
                    // Current is either (A, A) or (A, 0)
                    let ss = prevGenotype.1 // The non-null allele
                    let pNull = af[0]
                    let pS = af[Int(ss)]
                    let r = Double.random(in: 0..<1, using: &rng)
                    
                    if prevGenotype.0 == prevGenotype.1 { // (A, A) -> (A, 0)?
                        let probNullHet = (1.0 - F) * (2.0 * pS * pNull)
                        nextGenotype = (r < probNullHet) ? (0, ss) : (ss, ss)
                    } else { // (A, 0) -> (A, A)?
                        let probHom = (1.0 - F) * (pS * pS) + (F * pS)
                        nextGenotype = (r < probHom) ? (ss, ss) : (0, ss)
                    }
                } else {
                    // Fully imputed: Sample A1 ~ AF, then A2 from F-mixture
                    let startIdx = hasNullModel[locusIdx] ? 0 : 1
                    let a1 = sampleAllele(frequencies: af, startIdx: startIdx)
                    let a2: UInt8
                    if Double.random(in: 0..<1, using: &rng) < F {
                        a2 = a1
                    } else {
                        a2 = sampleAllele(frequencies: af, startIdx: startIdx)
                    }
                    nextGenotype = (min(a1, a2), max(a1, a2))
                }

                var nextState = currentState
                nextState.maternalGenotypes[i][locusIdx] = nextGenotype
                let nextFamilyLnL = calculateFamilyLogLikelihood(familyIndex: i, state: nextState)

                if nextFamilyLnL > prevFamilyLnL || Double.random(in: 0..<1, using: &rng) < exp(nextFamilyLnL - prevFamilyLnL) {
                    currentState.maternalGenotypes[i][locusIdx] = nextGenotype
                    totalLnL += (nextFamilyLnL - prevFamilyLnL)
                }
            }
            return totalLnL
        }

        private func sampleAllele(frequencies: [Double], startIdx: Int) -> UInt8 {
            let rand = Double.random(in: 0..<1, using: &rng)
            var cumulative = 0.0
            for i in startIdx..<frequencies.count {
                cumulative += frequencies[i]
                if rand < cumulative { return UInt8(i) }
            }
            return UInt8(frequencies.count - 1)
        }
    }
}
