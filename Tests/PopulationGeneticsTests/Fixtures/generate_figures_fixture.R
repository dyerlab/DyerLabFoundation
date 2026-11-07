# generate_figures_fixture.R
#
# Proves that R can read and write the figure tables of a project file, with nothing more than SQL and JSON, and
# produces the file that `FigureInteropTests` reads back in Swift. The functions at the top are the reference for
# the gstudio package's eventual `read_figures()` and `write_figure()`: the format is described in the
# PopulationGenetics catalog's figure storage article.
#
# Usage, from the package root:
#
#   GSTUDIO_FIGURE_FIXTURES=/some/empty/dir swift test --filter writesTheFilesRReads
#   Rscript Tests/PopulationGeneticsTests/Fixtures/generate_figures_fixture.R /some/empty/dir
#
# Needs DBI, RSQLite and jsonlite; ggplot2 and tibble to run stored R code.

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(jsonlite)
})

# MARK: - Reference reader

# Reads every figure in a project file, in list order, as a list. A file with no figures gives an empty list.
read_figures <- function(path) {
  con <- dbConnect(SQLite(), path, flags = SQLITE_RO)
  on.exit(dbDisconnect(con))
  if (!dbExistsTable(con, "figures")) return(list())
  figures <- dbGetQuery(con, "SELECT * FROM figures ORDER BY ordinal")
  lapply(seq_len(nrow(figures)), function(i) {
    figure <- as.list(figures[i, ])
    columns <- dbGetQuery(con, "SELECT name, kind, role, data FROM figure_columns WHERE figure_uuid = ?
                                ORDER BY position", params = list(figure$uuid))
    figure$values <- figure_values(columns)
    figure$roles <- setNames(columns$role[!is.na(columns$role)], columns$name[!is.na(columns$role)])
    figure$images <- dbGetQuery(con, "SELECT name, mime_type, width, height, data FROM figure_images
                                      WHERE figure_uuid = ? ORDER BY name", params = list(figure$uuid))
    figure
  })
}

# Rebuilds a figure's plotted values as a data frame from its stored columns.
figure_values <- function(columns) {
  values <- lapply(seq_len(nrow(columns)), function(i) {
    parsed <- fromJSON(columns$data[i])
    switch(columns$kind[i],
           number = as.numeric(parsed),
           text = as.character(parsed),
           date = as.POSIXct(as.character(parsed), format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  })
  names(values) <- columns$name
  as.data.frame(values, optional = TRUE, stringsAsFactors = FALSE)
}

# MARK: - Reference writer

# Identical to the component's statements in Swift, except for IF NOT EXISTS. `FigureInteropTests` compares them.
figure_tables <- c(
  "CREATE TABLE IF NOT EXISTS figures (
      ordinal    INTEGER PRIMARY KEY,
      uuid       TEXT NOT NULL UNIQUE,
      title      TEXT NOT NULL,
      legend     TEXT NOT NULL DEFAULT '',
      source     TEXT NOT NULL DEFAULT '',
      form       TEXT,
      bins       INTEGER,
      x_label    TEXT,
      y_label    TEXT,
      generator  TEXT,
      spec       TEXT,
      r_code     TEXT,
      created_at TEXT NOT NULL
  )",
  "CREATE TABLE IF NOT EXISTS figure_columns (
      figure_uuid TEXT NOT NULL REFERENCES figures(uuid),
      position    INTEGER NOT NULL,
      name        TEXT NOT NULL,
      kind        TEXT NOT NULL CHECK (kind IN ('number', 'text', 'date')),
      role        TEXT CHECK (role IN ('x', 'y', 'series', 'label')),
      data        TEXT NOT NULL,
      PRIMARY KEY (figure_uuid, position),
      UNIQUE (figure_uuid, name),
      UNIQUE (figure_uuid, role)
  )",
  "CREATE TABLE IF NOT EXISTS figure_images (
      figure_uuid TEXT NOT NULL REFERENCES figures(uuid),
      name        TEXT NOT NULL,
      mime_type   TEXT NOT NULL,
      width       INTEGER,
      height      INTEGER,
      data        BLOB NOT NULL,
      PRIMARY KEY (figure_uuid, name)
  )")

iso8601 <- function(x) format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

new_uuid <- function() {
  hex <- function(n) paste(sample(c(0:9, letters[1:6]), n, replace = TRUE), collapse = "")
  paste(hex(8), hex(4), paste0("4", hex(3)), paste0(sample(c("8", "9", "a", "b"), 1), hex(3)), hex(12), sep = "-")
}

column_kind <- function(x) {
  if (inherits(x, c("POSIXt", "Date"))) "date" else if (is.numeric(x)) "number" else "text"
}

column_json <- function(x) {
  if (inherits(x, c("POSIXt", "Date"))) x <- iso8601(as.POSIXct(x))
  if (is.factor(x)) x <- as.character(x)
  if (is.numeric(x)) x[!is.finite(x)] <- NA
  as.character(toJSON(x, digits = NA, na = "null"))
}

# Adds a figure to a project file, or replaces the one with the same `id`, keeping its place in the list.
#
# `values` is a data frame, `roles` a named vector such as c(x = "pop", y = "He"), `form` one of histogram, density,
# bars or scatter, and `images` a named list of raw PNG bytes such as list(figure = png_bytes).
write_figure <- function(path, title, values = NULL, roles = character(), form = NULL, legend = "", bins = NULL,
                         x_label = NULL, y_label = NULL, r_code = NULL, generator = NULL, spec = NULL,
                         images = list(), id = new_uuid(), created_at = Sys.time()) {
  con <- dbConnect(SQLite(), path)
  on.exit(dbDisconnect(con))
  or_null <- function(x, type = NA_character_) if (is.null(x)) type else x
  dbWithTransaction(con, {
    for (statement in figure_tables) dbExecute(con, statement)
    dbExecute(con, "INSERT OR IGNORE INTO meta (key, value) VALUES ('figures_schema_version', '1')")
    dbExecute(con, "INSERT OR REPLACE INTO meta (key, value) VALUES ('has_figures', 'true')")
    ordinal <- dbGetQuery(con, "SELECT COALESCE((SELECT ordinal FROM figures WHERE upper(uuid) = upper(?)),
                                                (SELECT COALESCE(MAX(ordinal), -1) + 1 FROM figures)) AS n",
                          params = list(id))$n
    dbExecute(con, "DELETE FROM figure_columns WHERE upper(figure_uuid) = upper(?)", params = list(id))
    dbExecute(con, "DELETE FROM figure_images WHERE upper(figure_uuid) = upper(?)", params = list(id))
    dbExecute(con, "INSERT OR REPLACE INTO figures (ordinal, uuid, title, legend, source, form, bins, x_label,
                                                    y_label, generator, spec, r_code, created_at)
                    VALUES (?, ?, ?, ?, 'gstudio', ?, ?, ?, ?, ?, ?, ?, ?)",
              params = list(ordinal, id, title, legend, or_null(form), or_null(bins, NA_integer_), or_null(x_label),
                            or_null(y_label), or_null(generator), or_null(spec), or_null(r_code),
                            iso8601(created_at)))
    for (i in seq_along(values)) {
      name <- names(values)[i]
      role <- names(roles)[match(name, roles)]
      dbExecute(con, "INSERT INTO figure_columns (figure_uuid, position, name, kind, role, data)
                      VALUES (?, ?, ?, ?, ?, ?)",
                params = list(id, i - 1L, name, column_kind(values[[i]]), role, column_json(values[[i]])))
    }
    for (name in names(images)) {
      dbExecute(con, "INSERT INTO figure_images (figure_uuid, name, mime_type, data) VALUES (?, ?, 'image/png', ?)",
                params = list(id, name, list(images[[name]])))
    }
  })
  invisible(id)
}

# MARK: - The proof

args <- commandArgs(trailingOnly = TRUE)
swift_dir <- args[1]
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
fixtures <- dirname(script)
stopifnot(dir.exists(swift_dir))

# 1. R reads what Swift wrote.
swift_figures <- read_figures(file.path(swift_dir, "figures_from_swift.gstudio"))
stopifnot(length(swift_figures) == 2)
scatter <- swift_figures[[1]]
stopifnot(scatter$title == "He by locus",
          scatter$form == "bars",
          scatter$generator == "diversity_plot",
          fromJSON(scatter$spec)$response == "He",
          identical(unname(scatter$roles[["He"]]), "y"),
          identical(names(scatter$values), c("locus", "He")),
          all.equal(scatter$values$He, c(0.46875, 0.5)),
          identical(as.raw(c(0x89, 0x50, 0x4E, 0x47)), scatter$images$data[[1]][1:4]))

missing <- swift_figures[[2]]
stopifnot(is.na(missing$values$value[2]),
          is.na(missing$values$name[3]),
          inherits(missing$values$when, "POSIXct"),
          format(missing$values$when[1], tz = "UTC") == "2026-01-02 03:04:05")

# Code stored by Swift runs, and draws, against nothing but its own embedded values.
plot <- eval(parse(text = scatter$r_code), envir = new.env())
stopifnot(inherits(plot, "ggplot"))
pdf(NULL)
print(plot)
invisible(dev.off())
cat("R read the Swift figures and ran their code\n")

# 2. R adds figures to a file that predates them, and every other table is left alone.
out <- file.path(fixtures, "figures_from_r.gstudio")
unlink(out)
invisible(file.copy(file.path(swift_dir, "figures_base.gstudio"), out))
con <- dbConnect(SQLite(), out)
before <- setdiff(dbListTables(con), "meta") # Adding figures adds two rows to meta, and changes no others.
counts <- function(con, tables) {
  sapply(tables, function(table) dbGetQuery(con, sprintf("SELECT count(*) n FROM \"%s\"", table))$n)
}
counted <- counts(con, before)
dbDisconnect(con)
stopifnot(length(read_figures(out)) == 0)

set.seed(1)
he <- data.frame(population = c("Pop A", "Pop B", NA), He = c(0.41, NA, 0.5))
write_figure(out, "He by population from R", values = he, roles = c(x = "population", y = "He"), form = "bars",
             legend = "Written by gstudio.", x_label = "Population", y_label = "He",
             r_code = "ggplot2::ggplot()", id = "6f1e0e52-3f3a-4b63-9a55-1d2c3b4a5f60",
             created_at = as.POSIXct("2026-11-06 12:00:00", tz = "UTC"))

png_file <- tempfile(fileext = ".png")
png(png_file, width = 64, height = 48)
par(mar = c(0, 0, 0, 0))
plot(1:3)
invisible(dev.off())
png_bytes <- readBin(png_file, "raw", file.size(png_file))
image_id <- write_figure(out, "A picture from R", images = list(figure = png_bytes), form = "ridgeline",
                         generator = "gstudio_ridgeline", spec = '{"bandwidth":0.5}',
                         created_at = as.POSIXct("2026-11-06 12:00:01", tz = "UTC"))

# Replacing keeps the place in the list and drops the old children.
hist_id <- write_figure(out, "placeholder", values = data.frame(a = 1:2), roles = c(y = "a"), form = "density")
write_figure(out, "Ho, histogram", values = data.frame(Ho = c(0.1, 0.2, 0.2, 0.6, Inf)), roles = c(y = "Ho"),
             form = "histogram", bins = 4L, x_label = "Ho", y_label = "Count", id = hist_id,
             created_at = as.POSIXct("2026-11-06 12:00:02", tz = "UTC"))

con <- dbConnect(SQLite(), out)
stopifnot(identical(counts(con, before), counted),
          dbGetQuery(con, "SELECT value FROM meta WHERE key = 'figures_schema_version'")$value == "1",
          dbGetQuery(con, "SELECT value FROM meta WHERE key = 'has_figures'")$value == "true")
dbDisconnect(con)

from_r <- read_figures(out)
stopifnot(identical(sapply(from_r, `[[`, "title"), c("He by population from R", "A picture from R", "Ho, histogram")),
          identical(from_r[[3]]$values$Ho[5], NA_real_),
          identical(from_r[[2]]$images$data[[1]], png_bytes))
cat("R added figures to an older file and left its tables alone:", out, "\n")
