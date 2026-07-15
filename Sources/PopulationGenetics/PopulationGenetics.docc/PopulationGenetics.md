# ``PopulationGenetics``

A high-performance engine for population and landscape genetics: diploid marker storage, import, genetic
distance/diversity statistics, AMOVA, rarefaction, parentage, persistence, and population-graph views.

## Overview

`PopulationGenetics` stores and analyzes diploid marker data at scales from a few microsatellite loci to
chromosome-scale SNP panels. Genotypes are held locus-major as packed columns of allele indices addressed by
individual ordinal, so the same machinery serves both marker classes. It is the one domain-specific product in
this package — `Matrix`, `Graph`, and `PresentationZen` stay domain-agnostic; this is where genetics-specific
logic lives.

### Columnar core

- ``AlleleCodebook`` — per-locus allele index ↔ label map; index `0` is the NULL/missing allele in both SNP and microsatellite data.
- ``GenotypeColumn`` — locus-major column protocol, implemented by ``BiallelicColumn`` (2-bit packed SNP dosage) and ``MultiallelicColumn`` (microsatellite allele-index pairs).
- ``GenotypeMatrix`` — individuals × loci, materialized from a ``PopGenStore`` for algorithms and persistence.
- ``AlleleFrequencies`` — an incremental allele-count accumulator with diversity statistics (`A`, `A95`, `Ae`, `Ho`, `He`).
- ``PollenPoolFrequencies`` — maternal subtraction for mother/offspring parentage and pollen-pool analysis.

### Ergonomic access & import

- ``PopGenStore`` — a facade over the columnar core: growable staging arrays supporting incremental `add`/`set` mutation, for SwiftUI apps, importers, and simulations.
- ``ImportedDataset`` — the result of importing raw data: a `GenotypeMatrix` plus parentage/strata.
- `importPopulationTable`, `importMicrosatTable`, `importVCFTools012` — real-data importers for population/strata tables, microsatellite family tables, and vcftools `--012` SNP panels, configured via ``PopulationImportLayout`` / ``GenotypeImportLayout``.
- ``ExampleDataset`` — bundled sample datasets (`arapat.csv`, `cornus.csv`, the `phylog.012` triplet) imported through these same real import paths, so downstream apps can draw on real data without shipping their own copy. See ``ExampleData`` for raw-text access to the underlying resource files.

### Analysis

- ``GeneticDistanceMatrix`` / `geneticDistance` — Smouse & Peakall genetic distance.
- ``AMOVA`` (a thin domain-vocabulary wrapper over `Matrix`'s `DistanceVarianceDecomposition`) — variance decomposition and permutation testing, including `pairwisePhiST` for pairwise Φ_ST between strata.
- `genotypicRarefaction` / `allelicRarefaction` — individual-based resampling for diversity rarefaction.
- ``ParentageDesign`` / ``MaternalFamily`` / `paternalGamete` — pollen-pool parentage analysis.

### Persistence & spatial

- ``GenotypeMatrixStore`` — an actor-based SQLite store for a `GenotypeMatrix` and its population graph, safe to hold and `await` from any context.
- ``PopulationGraphDataset`` — a population graph paired with its spatial layout.
- ``PlacardMapView`` / ``MapPlacard`` — MapKit-backed views for a population graph.
- `pairwiseGreatCircleDistance` — spatial distance between sampling locations.
