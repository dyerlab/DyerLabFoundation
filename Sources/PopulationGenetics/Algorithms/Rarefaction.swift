//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  Rarefaction.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 6/5/25.
//

import Foundation
import Matrix

/// Performs rarefaction analysis on a collection of genotypes.
///
/// Rarefaction estimates genetic diversity at reduced sample sizes by repeatedly
/// resampling without replacement. This allows for fair comparison of diversity
/// between populations with different sample sizes.
///
/// Dispatches to `allelicRarefaction` for allele-pool-based metrics (`.A`,
/// `.A95`, `.Ae`) and `genotypicRarefaction` for the rest. `.A`/`.A95`/`.Ae`
/// also have an individual-based variant (preserves each individual's own
/// allele pairing rather than pooling alleles) — call `genotypicRarefaction`
/// directly for that; this convenience wrapper always uses the allele-pool
/// version for those three, matching the historical/default behavior.
///
/// - Parameters:
///   - genotypes: The array of genotypes to analyze.
///   - type: The diversity metric to compute (e.g., A, Ae, A95).
///   - size: The target subsample size (must be smaller than the full sample).
///   - iterations: Number of resampling iterations (defaults to 999).
///   - seed: PRNG seed, for reproducibility.
/// - Returns: A `NullDistributionResult` (observed diversity at full sample
///   size vs. the distribution of rarefied estimates), or `nil` if invalid parameters.
public func rarefaction(genotypes: [Genotype], type: DiversityType, size: Int, iterations: Int = 999, seed: UInt64) -> NullDistributionResult? {

    guard type != .Undefined else { return nil }

    if genotypes.isEmpty || size >= genotypes.count || iterations < 2 || size < 10 {
        return nil
    }

    if type.level == .Allelic {
        return allelicRarefaction(genotypes: genotypes, type: type, size: size, iterations: iterations, seed: seed)
    } else {
        return genotypicRarefaction(genotypes: genotypes, type: type, size: size, iterations: iterations, seed: seed)
    }
}

/// Performs individual-based rarefaction by resampling whole genotypes (not
/// decomposed alleles) without replacement — each sampled individual
/// contributes both of its alleles together, preserving the pairing that
/// `allelicRarefaction`'s allele-pool approach discards. This is the
/// "individual-based" vs. "gene-based" rarefaction distinction discussed in
/// the literature (e.g. Kalinowski 2004): the two can give different results
/// for the same data, and neither is universally "more correct" — which one
/// matches how you actually want to model resampling is a real choice.
///
/// Supports two kinds of metric, both computed via `GenotypeFrequencies` on
/// each subsample:
/// - **Allelic** (`.A`, `.A95`, `.Ae`): the individual-based counterpart to
///   what `allelicRarefaction` computes from an allele pool.
/// - **Genotypic** (`.Ho`, `.He`): single-population heterozygosity
///   statistics that only make sense computed from whole genotypes to begin
///   with — there's no allele-pool equivalent for these.
///
/// `.Ht`, `.Hi`, `.Hos`, `.Hes`, `.Pe`, and `.Undefined` are not supported
/// and return `nil`. The `.Ht`/`.Hi`/`.Hos`/`.Hes`/`.Pe` group are Nei-style
/// *hierarchical* measures (total vs. within-population heterozygosity,
/// etc.) that require explicit population/stratum partitioning this
/// function's flat `[Genotype]` signature has no way to express — silently
/// computing something for them would mean guessing at population structure
/// the caller never provided.
///
/// - Parameters:
///   - genotypes: The array of genotypes to analyze.
///   - type: The diversity metric to compute (`.A`, `.A95`, `.Ae`, `.Ho`, or `.He`).
///   - size: The target subsample size in genotypes.
///   - iterations: Number of resampling iterations (defaults to 999).
///   - seed: PRNG seed, for reproducibility.
/// - Returns: A `NullDistributionResult`, or `nil` if `type` is unsupported,
///   or `size`/`genotypes` are invalid.
public func genotypicRarefaction(genotypes: [Genotype], type: DiversityType, size: Int, iterations: Int = 999, seed: UInt64) -> NullDistributionResult? {
    guard type == .A || type == .A95 || type == .Ae || type == .Ho || type == .He else { return nil }
    guard !genotypes.isEmpty, size > 0, size < genotypes.count else { return nil }

    func value(_ freq: GenotypeFrequencies) -> Double {
        switch type {
        case .A: return freq.A
        case .A95: return freq.A95
        case .Ae: return freq.Ae
        case .Ho: return freq.Ho
        default: return freq.He
        }
    }

    return Resampling.subsampleTest(
        population: genotypes, size: size, iterations: iterations, seed: seed, tag: .rarefaction(type)
    ) { sample in
        value(GenotypeFrequencies(genotypes: sample))
    }
}

/// Performs allelic rarefaction by resampling alleles without replacement.
///
/// This function:
/// 1. Extracts all alleles from the genotypes (2N alleles from N diploid genotypes)
/// 2. Repeatedly samples a subset of alleles (2 × size alleles)
/// 3. Computes the diversity metric for each subsample, and for the full
///    allele pool (the observed value) — the same statistic both times,
///    confirmed equivalent to `GenotypeFrequencies.A`/`.A95`/`.Ae` computed
///    directly from `genotypes`, since both share the same non-empty-allele
///    filtering convention (`Genotype.ploidy` never leaves an empty allele
///    in a `.Diploid` genotype, and `.Haploid` always picks the non-empty one)
/// 4. Returns the distribution of rarefied diversity values
///
/// Supported metrics:
/// - **A**: Allelic richness (number of unique alleles)
/// - **A95**: Number of common alleles (frequency ≥ 5%)
/// - **Ae**: Effective number of alleles (1/Σp²)
///
/// - Parameters:
///   - genotypes: The array of genotypes to analyze.
///   - type: The allelic diversity metric to compute (A, A95, or Ae).
///   - size: The target subsample size in genotypes (will sample 2×size alleles).
///   - iterations: Number of resampling iterations (defaults to 999).
///   - seed: PRNG seed, for reproducibility.
/// - Returns: A `NullDistributionResult` with observed and rarefied diversity
///   values. If `size`/`genotypes` don't leave enough real (non-missing)
///   alleles to draw from, `observed` is `.nan` and `values` is empty rather
///   than throwing — check `values.isEmpty` before use.
public func allelicRarefaction(genotypes: [Genotype], type: DiversityType, size: Int, iterations: Int = 999, seed: UInt64) -> NullDistributionResult {
    let N = genotypes.count

    // Only non-missing alleles are eligible for resampling — a genotype with an
    // empty-string allele (haploid or fully missing) contributes 0 or 1 allele,
    // never a literal "" allele, matching `GenotypeFrequencies.addGenotype`'s
    // treatment of the same placeholder. `leftAllele`/`rightAllele` are
    // non-optional `String`, so `compactMap` here would silently do nothing —
    // an explicit `filter` is required.
    var alleles = genotypes.map { $0.leftAllele }.filter { !$0.isEmpty }
    alleles.append( contentsOf: genotypes.map { $0.rightAllele }.filter { !$0.isEmpty } )

    // `size >= N * 2` catches the common diploid-complete case cheaply; the
    // `alleles.count` check additionally guards against missing/haploid
    // genotypes shrinking the pool below `2 * size` alleles, which would
    // otherwise crash the slice below. This guard has no genotypic
    // equivalent, so it stays here rather than inside the shared engine.
    guard size < N * 2, 2 * size <= alleles.count else {
        return NullDistributionResult(analysisType: .rarefaction(type), observed: .nan, values: [], size: size)
    }

    func statistic(_ samp: [String]) -> Double {
        if type == .A {
            return Double(Set<String>(samp).count)
        } else {
            let hist = samp.valueCounts()
            var ctr = 0.0

            for (_, v) in hist {
                let f = v / Double(samp.count)

                if type == .A95 && f >= 0.05 {
                    ctr += 1.0
                }
                else if type == .Ae {
                    ctr += ( f * f )
                }
            }

            if type == .A95 {
                return ctr
            } else if type == .Ae && ctr > 0.0 {
                return 1.0 / ctr
            } else {
                return Double.nan
            }
        }
    }

    // `size` here is the number of *genotypes*; the engine draws exactly the
    // element count it's given from `population`, so the caller (this
    // function) is responsible for the ×2 allele-vs-genotype scaling —
    // matching every other unit the engine doesn't know about.
    return Resampling.subsampleTest(
        population: alleles, size: 2 * size, iterations: iterations, seed: seed, tag: .rarefaction(type)
    ) { sample in
        statistic(sample)
    }
}
