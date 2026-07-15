# ``Matrix``

Dense linear algebra and the general-purpose numeric foundations shared by every other product in this package.

## Overview

`Matrix` has no dependencies of its own — it is the base of the DyerLabFoundation product stack. `Graph`,
`PresentationZen`, and `PopulationGenetics` all build on it, and it stays domain-agnostic: nothing here knows
about graphs, charts, or genetics.

### Matrix & vector algebra

- ``Matrix`` — a dense, Accelerate-backed matrix type with Codable support and scalar/matrix operators.
- ``Vector`` — a `[Double]` typealias with numeric operators, binning, and natural-sort utilities.
- ``MatrixConvertible`` / ``VectorConvertible`` — conversion protocols for bridging other data shapes into a `Matrix` or `Vector`.
- ``rSourceConvertible`` — round-trips a value to R source, for scripting/export.

### Distance & variance

- ``DistanceMatrix`` / ``SymmetricUpperTriangle`` — symmetric pairwise-distance storage shared by every distance-based analysis downstream (genetic distance, spatial distance, relatedness).
- ``PairwiseMatrix`` / ``PairwiseMeasure`` — protocols a pairwise comparison type conforms to in order to plug into a `DistanceMatrix`.
- ``DistanceVarianceDecomposition``, ``DistanceVarianceDecompositionResult``, ``DistanceVarianceDecompositionProgress`` — AMOVA-style variance decomposition over a `DistanceMatrix`, with permutation-test progress reporting.

### Resampling & significance testing

- ``Resampling`` — generic permutation and subsample-test engines.
- ``NullDistributionResult`` / ``PermutationTestResult`` — the null-distribution and permutation-test result types shared across every domain that needs significance testing.
- ``AnalysisTag`` — an open tag identifying what a `NullDistributionResult` was computed for, so one result type serves every analysis.
- ``SplitMix64`` — a fast, seedable PRNG used wherever reproducible randomization is needed (permutation tests, simulation).

### Regression & probability

- ``LinearModelFit`` — standardized linear-model fitting.
- ``SigmaSearchResult`` — result of a bandwidth/sigma search (used by t-SNE affinity tuning).
- `tSNEAffinity` / `pairwiseTSNEAffinities` — t-SNE affinity calculation for embedding high-dimensional data.
- `hypergeometricProbability` — hypergeometric probability calculations.
