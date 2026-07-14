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
/// by importing `Data/arapat.csv` (repo-relative — see `loadAraptusSamples()`) through
/// `importPopulationTable`, the same pipeline a real import would use.
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

    /// The repo root, resolved from this source file's own location. Preview data is
    /// DEBUG-only development tooling reading straight from the checked-out repo, not
    /// a bundled resource — a real downstream app supplies its own sample data.
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // PopulationGeneticsPreviewData.swift -> DataStore/
            .deletingLastPathComponent() // DataStore/ -> PopulationGenetics/
            .deletingLastPathComponent() // PopulationGenetics/ -> Sources/
            .deletingLastPathComponent() // Sources/ -> repo root
    }

    /// Loads sample Araptus beetle genetic data by importing `Data/arapat.csv`.
    ///
    /// Populates the returned store with:
    /// - 8 microsatellite loci (LTRS, WNT, EN, EF, ZMP, AML, ATPS, MP20)
    /// - Adult individuals from Baja California sampling sites
    /// - A 3-level stratum hierarchy (Species > Cluster > Population)
    /// - Genotypes for each individual at each locus
    ///
    /// Returns an empty store if `Data/arapat.csv` can't be read or parsed — preview
    /// data is a convenience, not something callers should have to handle failure for.
    ///
    /// - Returns: A `PopGenStore` populated with the Araptus sample dataset.
    static public func loadAraptusSamples() -> PopGenStore {
        let url = repoRoot.appendingPathComponent("Data").appendingPathComponent("arapat.csv")
        guard let csv = try? String(contentsOf: url, encoding: .utf8),
              let dataset = try? importPopulationTable(csv: csv, layout: .init(
                  strataColumns: ["Species", "Cluster", "Population"],
                  nameColumn: "ID", latitudeColumn: "Latitude", longitudeColumn: "Longitude"
              ))
        else {
            return PopGenStore()
        }
        return PopGenStore(dataset: dataset)
    }
}

#endif
