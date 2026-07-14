//                      _                 _       _
//                   __| |_   _  ___ _ __| | __ _| |__
//                  / _` | | | |/ _ \ '__| |/ _` | '_ \
//                 | (_| | |_| |  __/ |  | | (_| | |_) |
//                  \__,_|\__, |\___|_|  |_|\__,_|_.__/
//                        |_ _/
//
//         Making Population Genetic Software That Doesn't Suck
//
//  MaternalFamily.swift
//  PopulationGenetics
//
//  Created by Rodney Dyer on 6/28/26.
//  Copyright (c) 2026 DyerLab LLC.  All Rights Reserved.
//

/// One maternal family: a mother (adult) and her sampled offspring, each an
/// individual ordinal into a ``GenotypeMatrix``.
public struct MaternalFamily: Sendable, Identifiable {

    /// Family label (the maternal-tree / momID identifier).
    public let id: String

    /// The mother's individual ordinal, or `nil` if no maternal tissue was sampled.
    public var mother: Int?

    /// Offspring individual ordinals.
    public var offspring: [Int]

    /// Creates a maternal family record.
    ///
    /// - Parameters:
    ///   - id: Family label (the maternal-tree identifier).
    ///   - mother: Individual ordinal of the mother, or `nil` if not sampled.
    ///   - offspring: Individual ordinals of all offspring in this family.
    public init(id: String, mother: Int?, offspring: [Int]) {
        self.id = id
        self.mother = mother
        self.offspring = offspring
    }

    /// Whether a maternal genotype is available for subtraction.
    public var hasMother: Bool { mother != nil }
}
