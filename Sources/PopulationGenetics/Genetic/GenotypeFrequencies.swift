//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  GenotypeFrequencies.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 6/2/25.
//

import Foundation

/// Computes and stores allele frequency data and genetic diversity statistics for a collection of genotypes.
///
/// This class accumulates allele counts from genotypes and provides computed properties for
/// common population genetic statistics including:
/// - Allelic richness (A, A95)
/// - Effective number of alleles (Ae)
/// - Observed heterozygosity (Ho)
/// - Expected heterozygosity/gene diversity (He)
///
/// Frequencies are accumulated incrementally using `addGenotype()` or `addGenotypes()`.
public class GenotypeFrequencies {

    /// Dictionary mapping allele names to their counts.
    public var counts: [String:Double]

    /// Number of heterozygous genotypes observed.
    public var numHets: Double

    /// Total number of genotypes processed.
    public var numGenos: Double

    /// Initializes an empty frequency object with no data.
    public init() {
        self.counts = [String:Double]()
        self.numHets = 0.0
        self.numGenos = 0.0
    }

    /// Initializes a frequency object and immediately processes the provided genotypes.
    ///
    /// - Parameter genotypes: An array of genotypes to compute frequencies from.
    public init( genotypes: [Genotype] ) {
        self.counts = [String:Double]()
        self.numHets = 0.0
        self.numGenos = 0.0
        self.addGenotypes(genos: genotypes )
    }


}


extension GenotypeFrequencies {

    /// Total number of alleles (sample size in allele counts).
    ///
    /// For diploid data, this is twice the number of genotypes.
    public var N: Double {
        return Double(  self.counts.values.reduce( 0.0, + ) )
    }

    /// Sorted list of all unique allele names observed.
    public var alleles: [String] {
        return self.counts.keys.sorted()
    }

    /// Adds a single genotype to the frequency calculations.
    ///
    /// This method processes the genotype based on its ploidy:
    /// - **Haploid**: Counts one allele
    /// - **Diploid**: Counts both alleles and tracks heterozygosity
    ///
    /// - Parameter geno: The genotype to add to the frequency data.
    public func addGenotype( geno: Genotype ) {

        if geno.ploidy == Genotype.Haploid {
            let allele = geno.leftAllele.isEmpty ? geno.rightAllele : geno.leftAllele
            counts[allele, default: 0.0] += 1.0
            numGenos += 1.0
        } else if geno.ploidy == Genotype.Diploid {
            counts[ geno.leftAllele, default: 0.0] += 1.0
            counts[ geno.rightAllele, default: 0.0] += 1.0
            if geno.isHeterozygote {
                self.numHets += 1.0
            }
            numGenos += 1.0
        }
    }

    /// Adds multiple genotypes to the frequency calculations.
    ///
    /// - Parameter genos: An array of genotypes to process.
    public func addGenotypes( genos: [Genotype] ) {
        genos.forEach({ addGenotype( geno: $0 ) } )
    }

    /// Returns the count of a specific allele.
    ///
    /// - Parameter allele: The allele name to query.
    /// - Returns: The integer count of the allele.
    public func count( for allele: String ) -> Int {
        return Int(counts[allele, default: 0.0])
    }

    /// Returns the frequency of a specific allele.
    ///
    /// - Parameter allele: The allele name to query.
    /// - Returns: The frequency as a proportion (0.0 to 1.0), or `NaN` if no data exists.
    public func frequency( for allele: String) -> Double {
        if N > 0 {
            return counts[allele, default: 0.0]  / N
        } else {
            return Double.nan
        }

    }

    /// Returns the frequencies for multiple alleles.
    ///
    /// - Parameter alleles: An array of allele names to query.
    /// - Returns: An array of frequencies in the same order as the input alleles.
    public func frequency( for alleles: [String] ) -> [Double] {
        var ret = [Double]()
        alleles.forEach( { ret.append( self.frequency(for: $0) ) } )
        return ret
    }

    /// Returns the frequencies for all alleles (sorted by allele name).
    ///
    /// - Returns: An array of frequencies for all alleles.
    public func frequencies() -> [Double] {
        return frequency(for: self.alleles)
    }

}


// MARK: - Genetic Diversity Statistics

extension GenotypeFrequencies {

    /// Allelic richness: the total number of unique alleles observed.
    ///
    /// This is a simple count of unique allele variants at the locus.
    public var A: Double {
        return Double( self.alleles.count )
    }

    /// Effective number of alleles: a measure of allelic diversity accounting for frequency distribution.
    ///
    /// Computed as: Ae = 1 / Σ(p²) where p is the frequency of each allele.
    /// Rare alleles contribute less to Ae than common alleles.
    ///
    /// - Returns: The effective number of alleles, or 0 if no data exists.
    public var Ae: Double {
        if self.counts.isEmpty {
            return 0.0
        }
        let freqs = self.frequency(for: self.alleles)
        return 1.0 / freqs.map{ $0 * $0 }.reduce( 0.0, + )
    }

    /// Number of common alleles (alleles with frequency ≥ 5%).
    ///
    /// This metric excludes very rare alleles from diversity calculations.
    public var A95: Double {
        return Double( self.frequencies().filter{ $0 >= 0.05 }.count )
    }

    /// Observed heterozygosity: the proportion of genotypes that are heterozygous.
    ///
    /// Computed as: Ho = (number of heterozygotes) / (total genotypes).
    ///
    /// - Returns: The observed heterozygosity, or `NaN` if no genotypes exist.
    public var Ho: Double {
        return numGenos > 0 ? numHets / numGenos : Double.nan
    }

    /// Expected heterozygosity (gene diversity): the probability that two randomly chosen alleles differ.
    ///
    /// Computed as: He = 1 - Σ(p²) where p is the frequency of each allele.
    /// Also known as Nei's gene diversity.
    ///
    /// - Returns: The expected heterozygosity.
    public var He: Double {
        let freqs = self.frequency(for: self.alleles)
        return 1.0 - freqs.map{ $0 * $0 }.reduce( 0.0, + )
    }



}







// MARK: - Export Functions

extension GenotypeFrequencies {

    /// Exports frequency data as an HTML table row.
    ///
    /// - Parameter alleles: Optional list of specific alleles to include. If empty, uses all alleles.
    /// - Returns: An HTML string representing a table row with frequency values.
    func asHTMLTableRow(alleles: [String] = [] ) -> String {
        let theAlleles = alleles.isEmpty ? self.alleles : alleles
        var ret = "<tr>\n"
        for allele in theAlleles {
            ret += "<td>\(self.frequency(for: allele))</td>\n"
        }
        ret += "</tr>\n"
        return ret
    }
}



extension GenotypeFrequencies {

    /// Returns a default frequency object for testing and preview purposes.
    ///
    /// Contains sample data with two alleles (A: 25%, B: 75%) and 37 heterozygotes out of 100 genotypes.
    static var defaultFrequencies: GenotypeFrequencies {
        let ret = GenotypeFrequencies()
        ret.counts = ["A":25.0,"B":75.0]
        ret.numHets = 37.0
        ret.numGenos = 100.0
        return ret
    }

}

extension GenotypeFrequencies: CustomStringConvertible {

    /// Returns a string representation showing the allele counts.
    public var description: String {
        return "Genotype Frequencies: \(self.counts)"
    }

}
