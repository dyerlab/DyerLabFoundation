//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  StoreComponents.swift
//  PopulationGenetics
//
//  Which of `ProjectStore`'s five independently-optional data kinds a given
//  file should hold. No component is privileged — a file can be genetic
//  data alone, graph+log alone, or any other combination. Each selected
//  component gets its own tables and its own schema-version row in `meta`;
//  see the `*SQLiteSchema.swift` files.
//

/// Which of `ProjectStore`'s data components to create (or that a file was
/// created with, on open).
public struct StoreComponents: OptionSet, Sendable {
    /// The raw bitmask value.
    public let rawValue: Int

    /// Initializes a component set from a raw bitmask value.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The genetic marker data: individuals, loci, genotypes, parentage.
    public static let geneticData = StoreComponents(rawValue: 1 << 0)
    /// A population graph derived from the genetic data (or standalone).
    public static let graph = StoreComponents(rawValue: 1 << 1)
    /// Markdown analysis writeups with attached images.
    public static let results = StoreComponents(rawValue: 1 << 2)
    /// A timestamped, append-only running log.
    public static let log = StoreComponents(rawValue: 1 << 3)
    /// Named, generic `Matrix` attachments (e.g. a derived distance matrix).
    public static let matrices = StoreComponents(rawValue: 1 << 4)

    /// Every component.
    public static let all: StoreComponents = [.geneticData, .graph, .results, .log, .matrices]
}
