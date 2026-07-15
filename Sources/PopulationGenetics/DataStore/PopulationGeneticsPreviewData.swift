//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  PreviewData.swift
// PopulationGenetics
//
//  Created by Rodney Dyer on 5/30/25.
//

import SwiftUI


#if DEBUG

/// Provides pre-populated sample data for SwiftUI previews and unit tests.
///
/// This singleton class loads sample Araptus beetle genetic data from Baja California
/// via `ExampleDataset.arapatPopulations` (see `loadAraptusSamples()`), the same
/// bundled resource and import pipeline a real user import would use.
///
/// - Note: Only available in DEBUG builds.
///
/// ## Usage
///
/// ```swift
/// // In SwiftUI previews
/// #Preview {
///     IndividualList()
///         .environmentObject(PopulationGeneticsPreviewData.shared.dataStore)
/// }
///
/// // In unit tests
/// let dataStore = PopulationGeneticsPreviewData.shared.dataStore
/// let stratum = dataStore.getStratum(named: "SBP", within: "Population")
/// ```
public final class PopulationGeneticsPreviewData: @unchecked Sendable {
    /// The shared singleton instance containing pre-loaded sample data.
    public static let shared = PopulationGeneticsPreviewData()

    /// The data store containing the sample genetic dataset.
    public let dataStore: PopGenStore

    /// Initializes a new preview data instance with sample Araptus data.
    public init() {
        self.dataStore = PopulationGeneticsPreviewData.loadAraptusSamples()
    }
}


extension PopulationGeneticsPreviewData {

    /// Sample loci for use in previews (randomly located on contig 1).
    static public var exampleLoci: [Locus] {

        let ret = [
            Locus(name: "LTRS", location: UInt.random(in: 1000...10000), contig: "1" ),
            Locus(name: "WNT", location: UInt.random(in: 1000...10000), contig: "1" ),
            Locus(name: "EN", location: UInt.random(in: 1000...10000), contig: "1" ),
            Locus(name: "EF", location: UInt.random(in: 1000...10000), contig: "1" ),
            Locus(name: "ZMP", location: UInt.random(in: 1000...10000), contig: "1" ),
            Locus(name: "AML", location: UInt.random(in: 1000...10000), contig: "1" ),
            Locus(name: "ATPS", location: UInt.random(in: 1000...10000), contig: "1" ),
            Locus(name: "MP20", location: UInt.random(in: 1000...10000), contig: "1" ),
        ]

        return ret.sorted()
    }

    /// Loads sample Araptus beetle genetic data via `ExampleDataset.arapatPopulations`.
    ///
    /// Populates the returned store with:
    /// - 8 microsatellite loci (LTRS, WNT, EN, EF, ZMP, AML, ATPS, MP20)
    /// - Adult individuals from Baja California sampling sites
    /// - A 3-level stratum hierarchy (Species > Cluster > Population)
    /// - Genotypes for each individual at each locus
    ///
    /// Returns an empty store if the bundled dataset can't be read or parsed — preview
    /// data is a convenience, not something callers should have to handle failure for.
    ///
    /// - Returns: A `PopGenStore` populated with the Araptus sample dataset.
    static public func loadAraptusSamples() -> PopGenStore {
        guard let dataset = try? ExampleDataset.arapatPopulations.load() else {
            return PopGenStore()
        }
        return PopGenStore(dataset: dataset)
    }
}

#endif
