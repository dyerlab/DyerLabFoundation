#!/usr/bin/env Rscript
# Generates gravity_congruence_fixtures.json for GravityCongruenceTests: gstudio's gravity_congruence() (1.15.5) on
#
# - "chain": chain_pair() from gstudio's tests/testthat/test-gravity_congruence.R (two 10-node chains sharing most
#   edges), gamma = 0.5 for both;
# - "gravity": Population Graphs of the bundled `gravity` genotypes (25 populations) from loci 1-10 and from loci
#   11-20, the second graph's nodes in reverse order and gamma = 1 for it, so populations are matched by name.
#
# Each case records both graphs (node order and weighted edges), the gammas, the seed and permutations, and the
# results: Spearman's rho and its label-permutation P (set.seed(seed) immediately before the call, so the
# sample.int(K) draws can be reproduced), the sign test, and the nodes and shared-edges tables.
#
# gstudio ranks S as it comes, so structurally equal scores that differ only in their last bits are ranked by
# rounding noise (Pop01-Pop07 in graph 2 of "gravity"). GravityCongruenceAnalysis merges near-ties first, with
# gstudio's own .merge_ties() as source_sink_test() does, so rho_merged and p_rho_merged repeat gravity_congruence()'s
# permutation loop, draw for draw, on the merged scores; that is what the Swift test checks.
#
#   Rscript generate_gravity_congruence_fixtures.R .
#
# Needs gstudio (>= 1.15.5), igraph and jsonlite.

suppressPackageStartupMessages({
  library(igraph)
  library(jsonlite)
  library(gstudio)
})
stopifnot(packageVersion("gstudio") >= "1.15.5")

fixture_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(fixture_dir)) stop("pass the output Fixtures dir as arg 1")

chain_pair <- function(K = 10, seed = 2) {
  set.seed(seed)
  nm <- paste0("P", seq_len(K))
  chain <- function(extra) {
    A <- matrix(0, K, K, dimnames = list(nm, nm))
    for (i in seq_len(K - 1)) A[i, i + 1] <- A[i + 1, i] <- stats::runif(1, 0.5, 2)
    for (e in extra) A[e[1], e[2]] <- A[e[2], e[1]] <- stats::runif(1, 2, 3)
    igraph::graph_from_adjacency_matrix(A, mode = "undirected", weighted = TRUE)
  }
  list(g1 = chain(list(c(2, 5), c(6, 9))), g2 = chain(list(c(2, 5), c(3, 8))))
}

graph_record <- function(g) {
  el <- as_edgelist(g, names = TRUE)
  list(nodes = V(g)$name,
       edges = data.frame(from = el[, 1], to = el[, 2], weight = E(g)$weight, stringsAsFactors = FALSE))
}

run_case <- function(g1, g2, gamma1, gamma2, seed, nperm) {
  # gravity_congruence() takes one gamma for graph inputs; a single-panel gravity_field carries its own.
  y <- if (gamma2 == gamma1) g2 else gravity_field(g2, gamma = gamma2)
  set.seed(seed)
  gc <- gravity_congruence(g1, y, gamma = gamma1, nperm = nperm)
  m1 <- gstudio:::.merge_ties(gc$nodes$S.1)
  m2 <- gstudio:::.merge_ties(gc$nodes$S.2)
  rho_merged <- stats::cor(m1, m2, method = "spearman")
  set.seed(seed)
  null <- vapply(seq_len(nperm), function(b)
    stats::cor(m1, m2[sample.int(length(m2))], method = "spearman"), numeric(1))
  p_rho_merged <- (1 + sum(null >= rho_merged - 1e-12, na.rm = TRUE)) / (1 + sum(!is.na(null)))
  list(graph1 = graph_record(g1), graph2 = graph_record(g2), gamma1 = gamma1, gamma2 = gamma2, seed = seed,
       nperm = nperm, rho = gc$tests$statistic[1], p_rho = gc$tests$p.value[1],
       rho_merged = rho_merged, p_rho_merged = p_rho_merged,
       edge_concordance = gc$tests$statistic[2], directed_edges = gc$tests$parameter[2],
       p_edge = gc$tests$p.value[2],
       nodes = gc$nodes[, c("Stratum", "S.1", "S.2", "gravity.1", "gravity.2", "degree.1", "degree.2",
                            "concordance")],
       edges = gc$edges[, c("from", "to", "weight.1", "weight.2", "delta.1", "delta.2", "concordant")])
}

cp <- chain_pair()
cases <- list(chain = run_case(cp$g1, cp$g2, 0.5, 0.5, seed = 1, nperm = 99))

data(gravity)
loci <- column_class(gravity, "locus")
pg <- function(l) popgraph(to_mv(gravity[, l]), gravity$Population)
g1 <- pg(loci[1:10])
g2 <- pg(loci[11:20])
g2 <- permute(g2, rev(seq_len(vcount(g2))))       # vertex i moves to position K - i + 1
cases$gravity <- run_case(g1, g2, 0.5, 1, seed = 3, nperm = 199)

write_json(cases, file.path(fixture_dir, "gravity_congruence_fixtures.json"), auto_unbox = TRUE, digits = NA,
           pretty = TRUE, na = "null")
