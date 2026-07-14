//
//  AlleleCodebook.swift
//  PopulationGenetics
//
//  Columnar core: maps compact `UInt8` allele indices to their human-readable
//  labels for one locus. Index 0 is reserved as the NULL / missing allele in
//  both SNP and microsatellite data, so a zero-initialized column reads as
//  "all missing".
//

import Foundation

/// A per-locus dictionary translating `UInt8` allele indices to string labels.
///
/// The codebook is the single home of human-readable allele names; packed
/// columns store only indices. Index `0` always denotes the absent / NULL
/// allele, so allele indices for real alleles begin at `1`. The number of
/// distinct non-null alleles is capped at 255.
public struct AlleleCodebook: Codable, Hashable, Sendable {

    /// Allele labels indexed by allele index. `labels[0]` is the empty NULL slot.
    public private(set) var labels: [String]

    /// The reserved index for the NULL / missing allele.
    public static let nullIndex: UInt8 = 0

    /// Creates an empty codebook containing only the NULL slot.
    public init() {
        self.labels = [""]
    }

    /// Creates a codebook registering the supplied allele labels in order.
    ///
    /// Empty strings and duplicates are ignored. The NULL slot is added
    /// automatically at index 0.
    ///
    /// - Parameter alleles: Allele labels to register; registration order determines index assignment.
    public init(alleles: [String]) {
        self.labels = [""]
        for allele in alleles where !allele.isEmpty {
            if !labels.contains(allele) {
                labels.append(allele)
            }
        }
    }

    /// Total number of slots, including the NULL slot at index 0.
    public var count: Int { labels.count }

    /// Number of distinct non-null alleles.
    public var alleleCount: Int { labels.count - 1 }

    /// Allele indices for all non-null alleles, in registration order (`1..<count`).
    public var alleleIndices: [UInt8] { (1..<labels.count).map { UInt8($0) } }

    /// Returns the index for a label, or `nil` if it is not registered.
    ///
    /// An empty string maps to `nullIndex`.
    public func index(of label: String) -> UInt8? {
        if label.isEmpty { return Self.nullIndex }
        guard let i = labels.firstIndex(of: label) else { return nil }
        return UInt8(i)
    }

    /// Returns the label for an allele index. Out-of-range indices return `""`.
    public func label(for index: UInt8) -> String {
        let i = Int(index)
        return i < labels.count ? labels[i] : ""
    }

    /// Registers a label, returning its allele index.
    ///
    /// Returns `nullIndex` for the empty string and the existing index if the
    /// label is already present. Precondition: fewer than 255 non-null alleles.
    @discardableResult
    public mutating func register(_ label: String) -> UInt8 {
        if label.isEmpty { return Self.nullIndex }
        if let existing = index(of: label) { return existing }
        precondition(labels.count < 256, "AlleleCodebook is limited to 255 non-null alleles")
        labels.append(label)
        return UInt8(labels.count - 1)
    }
}
