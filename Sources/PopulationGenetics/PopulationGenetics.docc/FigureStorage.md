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
| `name` | TEXT | `thumbnail` for a list, `figure` for full resolution, `null_distribution` for a tested result's permutation density; other names are kept |
| `mime_type` | TEXT | Such as `image/png` |
| `width`, `height` | INTEGER, nullable | Pixel size |
| `data` | BLOB | The image's bytes |

**`figure_records`**, optional, at most one row per figure: what a figure records about the analysis that made it,
so it reads as a frozen result. Files written before the table existed lack it; it is additive, so its absence is
valid and it doesn't change `figures_schema_version`. Readers that don't know it ignore it; a writer that removes a
figure should remove its row too.

| Column | Type | Meaning |
| --- | --- | --- |
| `figure_uuid` | TEXT, primary key | The figure |
| `methods` | TEXT | The Methods text written when the analysis ran |
| `results` | TEXT | The Results text written when the analysis ran |
| `notes` | TEXT | The analysis's notes (units left out, warnings), as a JSON array of strings |
| `analyst_notes` | TEXT | The analyst's own notes on the result; `''` if none |
| `data_version` | TEXT, nullable | An opaque id of the data the analysis ran against, which the writing program changes with each edit to the data |
| `data_modified_at` | TEXT, nullable | When that data version was made, in the `created_at` format |
| `app_version` | TEXT, nullable | The version of the program that ran the analysis |

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

### Isolation-by-distance analyses

An isolation-by-distance analysis is one figure of form `scatter` with generator `ibd_analysis`, so its plot and its
results travel together. Its columns are the pairs tested: text columns `From` and `To`, then the separation as `x`
(`distance_km`, or `ln_distance_km` when log-transformed) and the genetic distance as `y` (`phi_st_linearized` for
Rousset's Φ_ST / (1 − Φ_ST), otherwise the measure's name, such as `nei`). `x_label` and `y_label` are the axis titles,
`r_code` draws the points and the regression line (`geom_abline`), and the `figure` image is the plot with its line.
The `spec` is an ``IBDSpec``, holding both the inputs and the results:

```json
{"genetic":{"level":"Population","measure":"phi_st"},"logSeparation":true,"method":"pearson","permutations":999,
 "result":{"intercept":-2.796,"p":0.001,"pairs":703,"r":0.503,"r2":0.253,"slope":0.793},"seed":42,
 "separation":{"level":"Population","measure":"great_circle","units":"km"},"transform":"rousset"}
```

`genetic` and `separation` are ``DistanceSpec``s (<doc:MatrixStorage>); the matrices aren't stored, since they can be
rebuilt from the project's genotypes and coordinates. `transform` is `none` or `rousset` (only for `phi_st`); `method`
is `pearson` or `spearman`, as vegan's `mantel()` takes it; `permutations` is 0 and `seed` absent when untested.
In `result`, `r` is the Mantel correlation, `p` its permutation P (absent when untested), `slope` and `intercept` the
least-squares line of `y` on `x`, `r2` that line's R², and `pairs` the pairs tested (pairs with a non-finite genetic
distance are left out). The permutations are vegan's for the same `seed`, so `set.seed(seed); vegan::mantel(x, y)`
reproduces `p`.

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
