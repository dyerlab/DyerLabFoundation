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
- `SingularValueDecomposition` / `MoorePenroseInverse` / `SymmetricEigendecomposition` — LAPACK-backed decompositions (the last matching R's `eigen(symmetric = TRUE)`, eigenvalues descending).

### Distance & variance

- ``DistanceMatrix`` / ``SymmetricUpperTriangle`` — symmetric pairwise-distance storage shared by every distance-based analysis downstream (genetic distance, spatial distance, relatedness).
- ``PairwiseMatrix`` / ``PairwiseMeasure`` — protocols a pairwise comparison type conforms to in order to plug into a `DistanceMatrix`.
- ``DistanceVarianceDecomposition``, ``DistanceVarianceDecompositionResult``, ``DistanceVarianceDecompositionProgress`` — AMOVA-style variance decomposition over a `DistanceMatrix`, with permutation-test progress reporting.

### Resampling & significance testing

- ``Resampling`` — generic permutation and subsample-test engines.
- ``NullDistributionResult`` / ``PermutationTestResult`` — the null-distribution and permutation-test result types shared across every domain that needs significance testing.
- ``AnalysisTag`` — an open tag identifying what a `NullDistributionResult` was computed for, so one result type serves every analysis.
- ``SplitMix64`` — a fast, seedable PRNG used wherever reproducible randomization is needed (permutation tests, simulation).
- `MoranSpectralRandomization` — Moran spectral randomization ("singleton", Wagner & Dray 2015): null replicates of a node-level variable that keep its mean, variance and spectral power on a weight matrix (gstudio's `msr_null()`; seeded draws match R's when the Moran eigenvalues are distinct).
- ``RMersenneTwister`` — a Mersenne-Twister that reproduces R's `set.seed()` / `runif()` / `sample()` bit-for-bit, for exact-parity testing of resampling ports against R.

### Regression & probability

- ``LinearModelFit`` — standardized linear-model fitting.
- `pearsonCorrelation` / `studentTCDF` / `studentTTwoSidedPValue` / `regularizedIncompleteBeta` — Pearson correlation and the Student's t distribution behind it, matching R's `cor.test(method = "pearson")`.
- `spearmanCorrelation` / `averageRanks` — Spearman's rank correlation on average ranks, matching R's `cor(method = "spearman")`.
- ``SigmaSearchResult`` — result of a bandwidth/sigma search (used by t-SNE affinity tuning).
- `tSNEAffinity` / `pairwiseTSNEAffinities` — t-SNE affinity calculation for embedding high-dimensional data.
- `hypergeometricProbability` — hypergeometric probability calculations.
