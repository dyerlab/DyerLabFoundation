# Matrix Storage

How a project file stores named matrices, so another program (the gstudio R package in particular) can read and
write them.

## Overview

A project's `.matrices` component is one table, `matrices`, at schema version 2 (`matrices_schema_version` in the
`meta` table, with `has_matrices` set to `true` once a matrix is stored):

| Column | Type | Holds |
|---|---|---|
| `ordinal` | INTEGER PRIMARY KEY | The matrix's position, from 0 |
| `uuid` | TEXT, unique | Its identifier |
| `name` | TEXT | Its name. A project keeps one matrix per name: readers take the highest ordinal of a name |
| `description` | TEXT, nullable | A sentence saying how it was made |
| `created_at` | TEXT | When it was stored, as ISO 8601 |
| `data` | BLOB | The matrix, as UTF-8 JSON (below) |
| `spec` | TEXT, nullable | JSON saying what the matrix holds (below), or NULL for a matrix with no spec |

Version 1 files have no `spec` column. They are read as having no spec, and are migrated in place
(`ALTER TABLE matrices ADD COLUMN spec TEXT`) when opened for writing.

### The data

`data` is a JSON object with three arrays: `values`, the cells **row by row**, and `rowNames` and `colNames`.

```json
{ "values": [0, 12.5, 12.5, 0], "rowNames": ["A", "B"], "colNames": ["A", "B"] }
```

In R: `matrix(x$values, nrow = length(x$rowNames), byrow = TRUE, dimnames = list(x$rowNames, x$colNames))`.

### Specs

`spec` is free for the writer to use. GeneticStudio doesn't store the distance matrices it computes: they are quick
to compute from the file's coordinates and genotypes and slow to read back (a matrix of 5,000 individuals takes under
a tenth of a second to compute, but is about 450 MB of JSON and takes seconds to decode). gstudio rebuilds the same
great-circle matrices with `strata_coordinates()` and `strata_distance()`. So the table holds matrices that can't be
rebuilt, such as ones R wrote, and GeneticStudio shows and keeps them exactly as stored.

When a matrix is a distance matrix, a ``DistanceSpec`` as its `spec` says so:

```json
{"level":"Population","measure":"great_circle","units":"km"}
```

- `measure`: `great_circle`, the haversine distance on a sphere of radius 6371 km, as gstudio's
  `strata_distance(mode = "Circle")` computes it; or a genetic distance, named as gstudio's `genetic_distance()` names
  its `mode`. Among individuals: `amova` (Smouse & Peakall's squared distance) and `bray` (Bray-Curtis, one minus the
  proportion of shared alleles). Among strata: `nei` (Nei 1978), `cavalli` (Cavalli-Sforza & Edwards' chord),
  `dps` (1 − Ps), `euclidean`, `cgd` (conditional genetic distance through the population graph) and `phi_st`
  (pairwise Φ_ST, which gstudio has no mode for). Each locus uses only the units genotyped there, where gstudio counts
  a missing genotype as having no alleles; without missing data the two agree.
- `level`: `Individuals`, among the adults (every individual, or the mothers of parent/offspring data, whose offspring
  share their location), or a stratum level, among that level's strata. A stratum sits at the mean of its distinct
  coordinates, as gstudio's `strata_coordinates()` places it, and strata keep the order they first appear in.
- `units`: the distances' units, written for readers; absent for genetic distances, which have none.

The same JSON is what a saved distance analysis (a Mantel test, an isolation-by-distance plot, a tree) records to name
the matrices it was made from.

## Topics

### Reading and writing from Swift

- ``ProjectStore/addMatrix(_:name:description:spec:)``
- ``ProjectStore/matrices()``
- ``ProjectStore/matrixData(named:)``
- ``MatrixAttachment``
- ``DistanceSpec``
