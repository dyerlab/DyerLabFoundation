#!/usr/bin/env Rscript
# Generates R-reference fixtures for MantelAnalysis
# (Sources/Matrix/Analysis/MantelAnalysis.swift), a port of vegan's mantel().
# Run with vegan + jsonlite:
#
#   Rscript generate_mantel_fixtures.R Tests/MatrixTests/Fixtures
#
# Each case records the two full matrices, the seed, vegan's statistic, its
# permutation values ($perm) and p-value ($signif). vegan permutes its first
# argument, which MantelAnalysis calls the predictor: mantel(x, y) here is
# MantelAnalysis(response: y, predictor: x).

suppressPackageStartupMessages({
  library(vegan)
  library(jsonlite)
})

fixture_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(fixture_dir)) stop("pass the output Fixtures dir as arg 1")

make_case <- function(n, seed_data, seed_test, method, permutations) {
  set.seed(seed_data)
  coords <- cbind(runif(n), runif(n))
  x <- as.matrix(dist(coords))
  # A response that tracks x with noise, so r is clearly positive.
  noise <- matrix(rnorm(n * n, sd = 0.3), n, n)
  y <- x + (noise + t(noise)) / 2
  diag(y) <- 0
  set.seed(seed_test)
  m <- mantel(as.dist(x), as.dist(y), method = method, permutations = permutations)
  list(n = n, seed = seed_test, method = method, permutations = permutations,
       predictor = unname(x), response = unname(y),
       statistic = m$statistic, perm = as.numeric(m$perm), signif = m$signif)
}

cases <- list(
  pearson_n12  = make_case(12, 1, 42, "pearson", 199),
  spearman_n12 = make_case(12, 2, 7, "spearman", 199),
  pearson_n25  = make_case(25, 3, 2026, "pearson", 99)
)

write_json(cases, file.path(fixture_dir, "mantel_fixtures.json"),
           auto_unbox = TRUE, digits = NA, pretty = TRUE)
cat("vegan", as.character(packageVersion("vegan")), "\n")
