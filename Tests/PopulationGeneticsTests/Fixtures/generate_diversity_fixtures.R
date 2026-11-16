# Generates diversity_fixtures.json for DiversityFixtureTests.
#
# Per-locus diversity from gstudio's genetic_diversity() (1.15.5) on arapat_genotypes.csv, over the whole sample and
# within each Population: A, Ae, A95, He, Ho, Fis, Pe, Sh (Shannon, natural log) and Pex (exclusion probability with
# one known parent, Jamieson & Taylor 1997), plus the combined multilocus Pex, 1 - prod(1 - Pex), and Dm, the fraction
# of distinct multilocus genotypes, per Population. A locus with no genotypes in a stratum is NA (gstudio 1.15.4).
#
# Run from this directory:  Rscript generate_diversity_fixtures.R
# Needs gstudio (>= 1.15.4) and jsonlite.

suppressPackageStartupMessages({
  library(gstudio)
  library(jsonlite)
})

raw <- read.csv("arapat_genotypes.csv", colClasses = "character")
loci <- names(raw)[3:ncol(raw)]
df <- data.frame(Population = raw$Population, stringsAsFactors = FALSE)
for (l in loci) df[[l]] <- locus(raw[[l]], type = "separated")

modes <- c("A", "Ae", "A95", "He", "Ho", "Fis", "Pe", "Sh", "Pex")
per_locus <- function(x) {
  d <- suppressWarnings(genetic_diversity(x, mode = modes))
  lapply(loci, function(l) {
    r <- d[d$Locus == l, ]
    c(list(locus = l), setNames(lapply(modes, function(m) r[[m]]), modes))
  })
}

overall <- per_locus(df)
strata <- lapply(sort(unique(df$Population)), function(p) {
  x <- df[df$Population == p, ]
  pex <- suppressWarnings(genetic_diversity(x, mode = "Pex"))
  list(stratum = p, individuals = nrow(x), loci = per_locus(x),
       pexMultilocus = pex$Pex[pex$Locus == "Multilocus"],
       dm = genetic_diversity(x, mode = "Dm")$Dm)
})

write_json(list(overall = overall, strata = strata), "diversity_fixtures.json", auto_unbox = TRUE, digits = NA,
           pretty = TRUE, na = "null")
