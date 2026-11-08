# Figure Storage

How a project file holds figures, so that apps and R can each read and write them.

## Overview

A figure in a `.gstudio` file is plain SQL rows and JSON text. R needs only `DBI`, `RSQLite` and `jsonlite`, with no
compiled code from this package. A figure made in R opens in an app, and a figure made in an app can be read, redrawn
and rerun in R.

`Tests/PopulationGeneticsTests/Fixtures/generate_figures_fixture.R` holds a working reader and writer. It runs against
files written by Swift, and it writes the file that `FigureInteropTests` reads back, so that a change to either side
that breaks the other fails a test.

### How a program draws a figure

A figure holds up to three descriptions, and a program uses the best one it understands:

1. A `generator` it knows, with `spec`, recomputes the figure from the project's current data.
2. A `form` it knows redraws the stored values natively.
3. Otherwise the stored images are shown as they are.

A figure is never dropped for holding something a program doesn't understand. A program keeps the fields it can't
interpret and writes them back when it saves.

### Tables

The tables are created when a file first holds a figure. Files without them are valid, and have no figures.

Bump `figures_schema_version` for any change that would break an existing reader or writer.

**`figures`**, one row per figure:

| Column | Type | Meaning |
| --- | --- | --- |
| `ordinal` | INTEGER, primary key | Position in the list |
| `uuid` | TEXT, unique | Identity; any letter case |
| `title` | TEXT | Title |
| `legend` | TEXT | Legend; `''` if none |
| `source` | TEXT | The program that made it, such as `GeneticStudio` or `gstudio` |
| `form` | TEXT, nullable | `histogram`, `density`, `bars` or `scatter` for a plot, `table` for a results table; another name is kept but can't be drawn; `NULL` for images only |
| `bins` | INTEGER, nullable | Bins, for a histogram |
| `x_label`, `y_label` | TEXT, nullable | Axis titles |
| `generator` | TEXT, nullable | The code that can recompute it, such as `diversity_plot` or `amova_table` |
| `spec` | TEXT, nullable | The generator's parameters, as JSON whose meaning belongs to the generator |
| `r_code` | TEXT, nullable | R code that redraws it |
| `created_at` | TEXT | UTC time as `YYYY-MM-DDTHH:MM:SSZ` |

**`figure_columns`**, one row per plotted column:

| Column | Type | Meaning |
| --- | --- | --- |
| `figure_uuid` | TEXT | The figure |
| `position` | INTEGER | Column order, from 0 |
| `name` | TEXT | Column name, unique within the figure |
| `kind` | TEXT | `number`, `text` or `date` |
| `role` | TEXT, nullable | `x`, `y`, `series` or `label`, each used at most once in a figure |
| `data` | TEXT | The values as a JSON array of the same length in every column |

Missing values are JSON `null`, including NaN and infinities. Dates are strings in the `created_at` format.

**`figure_images`**, one row per picture:

| Column | Type | Meaning |
| --- | --- | --- |
| `figure_uuid` | TEXT | The figure |
| `name` | TEXT | `thumbnail` for a list, `figure` for full resolution; other names are kept |
| `mime_type` | TEXT | Such as `image/png` |
| `width`, `height` | INTEGER, nullable | Pixel size |
| `data` | BLOB | The image's bytes |

### Which columns each form needs

| Form | Needs |
| --- | --- |
| `histogram`, `density` | `y`, a number column holding the values |
| `bars` | `x`, and `y`, a number column |
| `scatter` | `x` and `y`, both number columns |
| `table` | Any columns, without roles, shown as a table in column order |

A figure that doesn't meet these is shown from its images instead.

### Results tables

A results table, such as an AMOVA, is a figure of form `table`. Its columns are the table's columns in order, a
missing value is an empty cell, and `x_label`, `y_label` and `bins` are `NULL`. Its `r_code` prints it with
`knitr::kable()` in a chunk labelled `tbl-…`. A structure table has generator `amova_table` and one of two layouts.
A variance-components table has the columns `Source`, `df`, `SS`, `MS`, `sigma2`, then `Phi_ST` (an AMOVA) or `F`
(Weir & Cockerham: θ, F_IS and F_IT), then `P` if it was tested; summed over loci genotyped in different numbers of
individuals, `df` and `MS` are missing. A by-locus table has `Locus`, `N`, `Alleles`, `Hs` and `Ht` (adults only), one
column per statistic (`theta`, `F_IS`, `F_IT`, `Phi_ST`, `Phi_ST_genotypes`, `Gst`, `Gst_prime`, `Dest`), each tested
statistic followed by its `P_` column, and a text column `Warning` if any locus's Gst or Dest is flagged; its last row,
`Multilocus`, holds ratios of sums over loci. The `spec` is a ``StructureSpec``:

```json
{"columns":["theta","phiGeneCopies","gst","gstPrime","dest"],"level":"Population","locus":"LTRS",
 "permutations":999,"sample":"adults","seed":42,"statistic":"phiGeneCopies","table":"perLocus",
 "thresholds":{"destAlleles":3,"destDiversity":0.3,"gstAlleles":7,"gstDiversity":0.6}}
```

`sample` is `adults` or `paternalGametes`; `table` is `amova` or `perLocus`; `statistic` (the variance-components
statistic) is `phiGeneCopies`, `phiGenotypes`, `theta` or `phiGametes`; `locus` is absent for all loci; `seed` is
absent when `permutations` is 0. A spec without `table`, `statistic`, `columns` or `thresholds`, written before they
existed, reads as a variance-components table of `phiGenotypes` for every adult locus, `theta` for one adult locus and
`phiGametes` for gametes.

### The `meta` table

The first figure written to a file must add these rows to `meta`, whose other rows are left alone:

| `key` | `value` |
| --- | --- |
| `figures_schema_version` | `1` |
| `has_figures` | `true` |

### Reading and writing from R

```r
con <- DBI::dbConnect(RSQLite::SQLite(), "project.gstudio")
figures <- DBI::dbGetQuery(con, "SELECT * FROM figures ORDER BY ordinal")
columns <- DBI::dbGetQuery(con, "SELECT name, kind, role, data FROM figure_columns
                                 WHERE figure_uuid = ? ORDER BY position",
                           params = list(figures$uuid[1]))
He <- jsonlite::fromJSON(columns$data[columns$name == "He"])
```

Write values with `jsonlite::toJSON(x, digits = NA, na = "null")`. Both arguments matter: the default rounds numbers
to four digits, and the default for missing numbers is a string.

## Topics

### Reading and writing from Swift

- ``ProjectStore/writeFigure(_:)``
- ``ProjectStore/figures()``
- ``ProjectStore/figure(id:)``
- ``ProjectStore/removeFigure(id:)``
- ``ProjectSnapshot/refreshingFigures()``
