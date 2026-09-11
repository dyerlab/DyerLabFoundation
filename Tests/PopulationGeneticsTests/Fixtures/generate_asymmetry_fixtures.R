#!/usr/bin/env Rscript
# Generates R-reference fixtures for the genotype-driven resampling ports
# (Phase 2b): asymmetry_permutation(), asymmetry_jackknife(), and
# permute_popgraph(), from Sources/PopulationGenetics/PopulationGraph/
# {AsymmetryPermutation,AsymmetryJackknife,PermutePopgraph}.swift. Run with
# gstudio >= 1.14.1 (permute_popgraph's per-stratum resampling fix) + igraph +
# jsonlite.
#
# Reuses the same real datasets (arapat, cornus) and to_mv()/groups() pairing
# already validated bit-identical to Swift's PopulationGraph() in
# PopulationGraphTests.swift, so this fixture only needs to pin the RNG seed
# for exact parity.

suppressPackageStartupMessages({
  library(igraph)
  library(jsonlite)
  library(gstudio)
})
stopifnot(packageVersion("gstudio") >= "1.14.1")

fixture_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(fixture_dir)) stop("pass the output Fixtures dir as arg 1")

sig_table <- function(df) {
  data.frame(from = as.character(df$from), to = as.character(df$to),
             delta = df$delta, statistic = df$statistic,
             p_value = df$p_value, ci_low = df$ci_low, ci_high = df$ci_high,
             stringsAsFactors = FALSE)
}

stability_table <- function(g) {
  el <- igraph::as_edgelist(g, names = TRUE)
  data.frame(from = el[, 1], to = el[, 2],
             weight = igraph::E(g)$weight, probability = igraph::E(g)$probability,
             stringsAsFactors = FALSE)
}

result <- list()
for (spec in list(list(name = "cornus", nperm = 200, nboot = 80, seed_perm = 6061, seed_jack = 7071, seed_boot = 8081),
                  list(name = "arapat", nperm = 60,  nboot = 40, seed_perm = 6062, seed_jack = 7072, seed_boot = 8082))) {
  name <- spec$name
  dataset <- get(data(list = name, package = "gstudio"))
  mv <- to_mv(dataset)
  groups <- dataset$Population
  g <- popgraph(mv, groups)
  class(g) <- c("popgraph", "igraph")

  set.seed(spec$seed_perm)
  perm <- asymmetry_permutation(g, mv, groups, nperm = spec$nperm)

  set.seed(spec$seed_jack)
  jack <- asymmetry_jackknife(g, mv, groups, nperm = spec$nperm, conf = 0.95)

  set.seed(spec$seed_boot)
  boot <- permute_popgraph(mv, groups, nboot = spec$nboot)

  result[[name]] <- list(
    nperm = spec$nperm,
    nboot = spec$nboot,
    permutation = list(seed = spec$seed_perm, rows = sig_table(perm)),
    jackknife   = list(seed = spec$seed_jack, conf = 0.95, rows = sig_table(jack)),
    permute_popgraph = list(seed = spec$seed_boot, rows = stability_table(boot))
  )
  cat(name, "done\n")
}

write_json(result, file.path(fixture_dir, "asymmetry_permutation_fixtures.json"),
           auto_unbox = TRUE, digits = 17, pretty = TRUE)
cat("wrote asymmetry_permutation_fixtures.json to", fixture_dir, "\n")
