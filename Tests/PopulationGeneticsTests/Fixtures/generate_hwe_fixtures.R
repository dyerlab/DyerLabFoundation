# Generates hwe_fixtures.json for HardyWeinbergTests.
#
# gstudio's hwe.test() (1.15.4) on arapat_genotypes.csv, over the whole sample and within each Population: the
# chi-square statistic against Hardy-Weinberg proportions, its degrees of freedom l(l - 1)/2, the upper-tail P and
# whether the continuity correction (|O - E| - 1/2, used when any expected count is under 5) was applied. Tests with
# no degrees of freedom (a single allele in the stratum) are left out, as HardyWeinbergAnalysis has none for them, and so
# are strata with no genotypes at a locus.
#
# It also records pchisq(x, df, lower.tail = FALSE) and binom.test(k, n, p, alternative = "greater") over a grid, for
# Matrix's chiSquareUpperTail and binomialUpperTail.
#
# Run from this directory:  Rscript generate_hwe_fixtures.R
# Needs gstudio (>= 1.15.4) and jsonlite.

suppressPackageStartupMessages({
  library(gstudio)
  library(jsonlite)
})

raw <- read.csv("arapat_genotypes.csv", colClasses = "character")
loci <- names(raw)[3:ncol(raw)]
df <- data.frame(Population = raw$Population, stringsAsFactors = FALSE)
for (l in loci) df[[l]] <- locus(raw[[l]], type = "separated")

rows <- function(tab) {
  tab <- tab[tab$df > 0, ]
  lapply(seq_len(nrow(tab)), function(i) list(
    locus = tab$Locus[i], statistic = tab$statistic[i], df = tab$df[i], p = tab$p.value[i],
    corrected = grepl("continuity", tab$method[i])))
}
overall <- rows(hwe.test(df, suppress_warnings = TRUE))
# hwe.test(df, stratum = "Population") stops at a stratum with an ungenotyped locus (genotype_frequencies() can't
# build its table from no genotypes), so each stratum and locus is tested on its own and those cells are skipped.
strata <- list()
for (p in unique(df$Population)) for (l in loci) {
  x <- df[[l]][df$Population == p]
  if (all(is.na(x))) next
  r <- hwe.test(x, suppress_warnings = TRUE)
  if (r$parameter > 0)
    strata[[length(strata) + 1]] <- list(stratum = p, locus = l, statistic = unname(r$statistic),
                                         df = unname(r$parameter), p = r$p.value,
                                         corrected = grepl("continuity", r$method))
}

grid <- expand.grid(x = c(0.01, 0.5, 1, 3.84, 10, 45, 120, 700), df = c(1, 2, 3, 6, 15, 45, 300))
chisq <- lapply(seq_len(nrow(grid)), function(i)
  list(x = grid$x[i], df = grid$df[i], p = pchisq(grid$x[i], grid$df[i], lower.tail = FALSE)))
binom <- list()
for (n in c(1, 5, 12, 40, 200)) for (k in unique(round(c(0, 1, n / 3, n / 2, n - 1, n)))) for (p in c(0.2, 0.5, 0.9))
  binom[[length(binom) + 1]] <- list(k = k, n = n, prob = p,
                                     p = binom.test(k, n, p, alternative = "greater")$p.value)

write_json(list(overall = overall, strata = strata, chisq = chisq, binom = binom), "hwe_fixtures.json",
           auto_unbox = TRUE, digits = NA, pretty = TRUE)
