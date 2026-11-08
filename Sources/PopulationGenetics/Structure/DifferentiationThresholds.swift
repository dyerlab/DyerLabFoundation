//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DifferentiationThresholds.swift
//  PopulationGenetics
//
//  When to flag Gst and Dest at a locus. Gst is bounded by the diversity
//  within strata, so with many alleles or high Hs it stays small however
//  different the strata are (Hedrick 2005; Jost 2008). Dest swings widely
//  when there is little diversity to measure. The flags only inform: the
//  values are always reported.
//
//  Created by Rodney Dyer on 2026.11.07.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Matrix

/// The allele counts and diversities at which a locus's Gst or Dest is flagged.
public struct DifferentiationThresholds: Codable, Hashable, Sendable {

    /// Gst is flagged at a locus with at least this many alleles.
    public var gstAlleles: Int
    /// Gst is flagged at a locus whose Hs is above this.
    public var gstDiversity: Double
    /// Dest is flagged at a locus with at most this many alleles.
    public var destAlleles: Int
    /// Dest is flagged at a locus whose Hs is below this.
    public var destDiversity: Double

    /// Creates the thresholds.
    ///
    /// - Parameters:
    ///   - gstAlleles: Gst is flagged at this many alleles or more (default 7).
    ///   - gstDiversity: Gst is flagged above this Hs (default 0.6).
    ///   - destAlleles: Dest is flagged at this many alleles or fewer (default 3).
    ///   - destDiversity: Dest is flagged below this Hs (default 0.3).
    public init(gstAlleles: Int = 7, gstDiversity: Double = 0.6, destAlleles: Int = 3, destDiversity: Double = 0.3) {
        self.gstAlleles = gstAlleles
        self.gstDiversity = gstDiversity
        self.destAlleles = destAlleles
        self.destDiversity = destDiversity
    }

    /// Why Gst is doubtful at a locus.
    ///
    /// - Parameters:
    ///   - alleles: The alleles seen at the locus.
    ///   - hs: Its diversity within strata, or `nil` if it isn't known yet.
    /// - Returns: The reason, such as `"9 alleles"`, or `nil` if Gst is fine.
    public func gstConcern(alleles: Int, hs: Double?) -> String? {
        if alleles >= gstAlleles { return "\(alleles) alleles" }
        if let hs, hs > gstDiversity { return "Hs \(AnalysisReport.number(hs))" }
        return nil
    }

    /// Why Dest is doubtful at a locus.
    ///
    /// - Parameters:
    ///   - alleles: The alleles seen at the locus.
    ///   - hs: Its diversity within strata, or `nil` if it isn't known yet.
    /// - Returns: The reason, such as `"2 alleles"`, or `nil` if Dest is fine.
    public func destConcern(alleles: Int, hs: Double?) -> String? {
        if alleles <= destAlleles { return "\(alleles) alleles" }
        if let hs, hs < destDiversity { return "Hs \(AnalysisReport.number(hs))" }
        return nil
    }

    /// Why Gst is flagged, for legends and the log.
    var gstReason: String {
        "Gst is bounded by the diversity within strata, so at loci with \(gstAlleles) or more alleles or Hs above "
            + "\(AnalysisReport.number(gstDiversity)) it stays small however different the strata are (Hedrick "
            + "2005; Jost 2008)"
    }

    /// Why Dest is flagged, for legends and the log.
    var destReason: String {
        "Dest is unstable where there is little diversity to measure: at loci with \(destAlleles) or fewer alleles "
            + "or Hs below \(AnalysisReport.number(destDiversity))"
    }
}
