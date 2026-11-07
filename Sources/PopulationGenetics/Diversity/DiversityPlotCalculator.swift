//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  DiversityPlotCalculator.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 2026.11.06.
//  Copyright (c) 2021-2026 Administravia LLC.  All Rights Reserved.
//

import Foundation

/// Reduces genotype columns over sets of individuals, for a diversity plot.
public struct DiversityPlotCalculator {
    /// The genotypes.
    public let dataset: ImportedDataset
    /// The dataset's loci and groups.
    public let options: DiversityPlotOptions
    /// The statistic to compute.
    public let response: DiversityType

    /// Creates a calculator.
    ///
    /// - Parameters:
    ///   - dataset: The genotypes.
    ///   - options: The dataset's loci and groups.
    ///   - response: The statistic to compute.
    public init(dataset: ImportedDataset, options: DiversityPlotOptions, response: DiversityType) {
        self.dataset = dataset
        self.options = options
        self.response = response
    }

    /// Computes one value per locus for the chosen sample.
    ///
    /// - Parameter sample: The individuals each value comes from.
    /// - Returns: A name and value per locus, in matrix order; the value is `nil`
    ///   where the sample has no genotypes.
    public func locusValues(sample: DiversityPlotSpec.Sample) -> [(name: String, value: Double?)] {
        options.loci.indices.map { locus in
            let value: Double?
            switch sample {
            case .pooled:
                value = self.value(locus: locus, over: dataset.adultOrdinals)
            case .meanWithinGroups:
                value = mean(options.primaryGroups.compactMap { self.value(locus: locus, over: $0.ordinals) })
            case .group(let name):
                let ordinals = options.primaryGroups.first { $0.name == name }?.ordinals ?? []
                value = self.value(locus: locus, over: ordinals)
            }
            return (options.loci[locus], value)
        }
    }

    /// Computes a group's value at one locus, or its mean across loci.
    ///
    /// - Parameters:
    ///   - group: The group.
    ///   - locus: The locus, or `nil` to average across the loci the group has genotypes for.
    /// - Returns: The value, or `nil` if the group has no genotypes to compute it from.
    public func groupValue(_ group: DiversityPlotOptions.Group, locus: String?) -> Double? {
        if let locus, let index = options.loci.firstIndex(of: locus) {
            return value(locus: index, over: group.ordinals)
        }
        return mean(values(within: group))
    }

    /// Computes a group's value at every locus it has genotypes for.
    ///
    /// - Parameter group: The group.
    /// - Returns: One value per locus with genotypes, in matrix order.
    public func values(within group: DiversityPlotOptions.Group) -> [Double] {
        options.loci.indices.compactMap { value(locus: $0, over: group.ordinals) }
    }

    /// Finds a group's value on a continuous predictor.
    ///
    /// - Parameters:
    ///   - predictor: The predictor.
    ///   - group: The group.
    /// - Returns: The group's mean coordinate or sample size; `nil` if the group
    ///   has no coordinates or `predictor` isn't continuous.
    public func predictorValue(_ predictor: DiversityPlotSpec.Predictor,
                               for group: DiversityPlotOptions.Group) -> Double? {
        let individuals = group.ordinals.map { dataset.matrix.individuals[$0] }
        switch predictor {
        case .latitude: return mean(individuals.compactMap(\.latitude))
        case .longitude: return mean(individuals.compactMap(\.longitude))
        case .sampleSize: return Double(group.ordinals.count)
        default: return nil
        }
    }

    private func value(locus: Int, over ordinals: [Int]) -> Double? {
        response.value(of: dataset.matrix.frequencies(atLocus: locus, over: ordinals))
    }

    private func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
