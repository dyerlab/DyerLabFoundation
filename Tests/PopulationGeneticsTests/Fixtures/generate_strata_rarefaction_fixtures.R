# Generates strata_rarefaction_fixtures.json for StrataRarefactionTests.
#
# gstudio's rarefaction.test() (1.15.5) on arapat_genotypes.csv by Population, draw for draw (set.seed() just before
# each call):
#
# - "smallest": every per-locus mode, every locus, rarefied to the smallest genotyped Population at each locus,
#   25 subsamples, seed 7;
# - "fixed": Ae, Fis and Pex at the first four loci, rarefied to 8 individuals with na.rm = TRUE (Populations with
#   fewer than 8 are NA at that locus and left out of their multilocus rows), 30 subsamples, 90% intervals, seed 11.
#
# Each case records the strata in gstudio's order (levels(factor())), which the Swift test passes as `strata`, and
# every row: Stratum, Locus ("Multilocus" for the combined rows), Mode, N, size, observed, estimate, conf.low,
# conf.high and the resampled values.
#
# Run from this directory:  Rscript generate_strata_rarefaction_fixtures.R
# Needs gstudio (>= 1.15.5) and jsonlite.

suppressPackageStartupMessages({
  library(gstudio)
  library(jsonlite)
})

raw <- read.csv("arapat_genotypes.csv", colClasses = "character")
loci <- names(raw)[3:ncol(raw)]
df <- data.frame(Population = raw$Population, stringsAsFactors = FALSE)
for (l in loci) df[[l]] <- locus(raw[[l]], type = "separated")

run_case <- function(seed, ...) {
  set.seed(seed)
  r <- suppressWarnings(rarefaction.test(df, stratum = "Population", ...))
  rows <- lapply(seq_len(nrow(r)), function(i) list(
    stratum = r$Stratum[i], locus = r$Locus[i], mode = r$Mode[i], n = r$N[i], size = r$size[i],
    observed = r$observed[i], estimate = r$estimate[i], low = r$conf.low[i], high = r$conf.high[i],
    values = r$values[[i]]))
  list(seed = seed, strata = levels(factor(df$Population)), rows = rows)
}

cases <- list(
  smallest = c(run_case(7, mode = c("A", "Ae", "A95", "He", "Ho", "Fis", "Pe", "Sh", "Pex"), nperm = 25),
               list(loci = loci, modes = c("A", "Ae", "A95", "He", "Ho", "Fis", "Pe", "Sh", "Pex"), nperm = 25,
                    size = NULL, confLevel = 0.95, naRm = FALSE)),
  fixed = c(run_case(11, mode = c("Ae", "Fis", "Pex"), loci = loci[1:4], size = 8, nperm = 30, conf.level = 0.9,
                     na.rm = TRUE),
            list(loci = loci[1:4], modes = c("Ae", "Fis", "Pex"), nperm = 30, size = 8, confLevel = 0.9,
                 naRm = TRUE)))

write_json(cases, "strata_rarefaction_fixtures.json", auto_unbox = TRUE, digits = NA, na = "null", null = "null")
