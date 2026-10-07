#!/usr/bin/env Rscript
# Generates R-reference fixtures for the genetic-gravity ports in
# Sources/Graph/Extensions/GeneticGravity.swift (neighbourhood_weights(),
# gravity_edges(), source_sink_scores(), pgd()) and, for the genotype-driven
# genetic_distance(mode = "pgd"), the `gravity` genotypes in
# Tests/PopulationGeneticsTests/Fixtures/. Run with gstudio >= 1.15.0 + igraph +
# jsonlite:
#
#   Rscript generate_gravity_fixtures.R Tests/GraphTests/Fixtures
#
# Graphs mirror gstudio's tests/testthat/test-gravity.R (make_chain()), plus the
# Population Graph of the bundled `gravity` dataset. NA (diagonal of W, S0 of an
# isolated node) and Inf (unreachable pGD) are written as JSON null.

suppressPackageStartupMessages({
  library(igraph)
  library(jsonlite)
  library(gstudio)
})
stopifnot(packageVersion("gstudio") >= "1.15.0")

fixture_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(fixture_dir)) stop("pass the output Fixtures dir as arg 1")
pg_fixture_dir <- file.path(fixture_dir, "..", "..", "PopulationGeneticsTests", "Fixtures")

# From gstudio's test-gravity.R.
make_chain <- function(K = 10, seed = 1, extra = list(c(2, 5), c(6, 9)), prefix = "P") {
  set.seed(seed)
  nm <- paste0(prefix, seq_len(K))
  A <- matrix(0, K, K, dimnames = list(nm, nm))
  for (i in seq_len(K - 1)) A[i, i + 1] <- A[i + 1, i] <- stats::runif(1, 0.5, 2)
  for (e in extra) A[e[1], e[2]] <- A[e[2], e[1]] <- stats::runif(1, 2, 3)
  igraph::graph_from_adjacency_matrix(A, mode = "undirected", weighted = TRUE)
}

edge_table <- function(g) {
  el <- as_edgelist(g, names = TRUE)
  data.frame(from = el[, 1], to = el[, 2], weight = E(g)$weight, stringsAsFactors = FALSE)
}

row_list <- function(M) lapply(seq_len(nrow(M)), function(i) unname(M[i, ]))

scores_record <- function(s) {
  attrs <- list(degree_share = attr(s, "degree_share"),
                cor_S_S0 = attr(s, "cor_S_S0"),
                cor_S_degree = attr(s, "cor_S_degree"),
                gradient_share = attr(s, "gradient_share"))
  if (!is.null(attr(s, "dbar_decomposition")))
    attrs$dbar_decomposition <- as.list(attr(s, "dbar_decomposition"))
  c(list(rows = data.frame(Stratum = s$Stratum, S = s$S, gravity = s$gravity,
                           balance = s$balance, degree = s$degree,
                           component = s$component, S0 = s$S0, n = s$n,
                           stringsAsFactors = FALSE)),
    attrs)
}

gamma_record <- function(g, gamma, x = NULL) {
  ed <- gravity_edges(g, gamma = gamma, x = x)
  rec <- list(
    gamma = if (is.infinite(gamma)) "Inf" else gamma,
    W = row_list(neighbourhood_weights(g, gamma = gamma)),
    edges = data.frame(from = ed$from, to = ed$to, weight = ed$weight,
                       w_from = ed$w_from, w_to = ed$w_to,
                       Delta = ed$Delta, Delta0 = ed$Delta0, stringsAsFactors = FALSE),
    scores = scores_record(source_sink_scores(g, gamma = gamma, x = x))
  )
  # pGD is not defined for the flat kernel's purpose here; omit the key (a NULL
  # element would serialise as {}).
  if (!is.infinite(gamma)) rec$pgd <- row_list(pgd(g, gamma = gamma, output = "matrix"))
  rec
}

case_record <- function(g, gammas, x = NULL) {
  rec <- list(nodes = V(g)$name,
              edges = edge_table(g),
              cases = lapply(gammas, function(gm) gamma_record(g, gm, x)))
  if (!is.null(x)) rec$x <- as.list(setNames(as.numeric(x), V(g)$name))
  rec
}

# A disconnected graph: two chains plus an isolated node.
g_disjoint <- disjoint_union(make_chain(5, extra = list()),
                             make_chain(4, seed = 2, extra = list(), prefix = "Q"))
g_disjoint <- add_vertices(g_disjoint, 1, name = "Z")

# The Population Graph of the bundled `gravity` dataset (25 demes, 81 edges).
data(gravity, package = "gstudio", envir = environment())
g_gravity <- popgraph(to_mv(gravity), gravity$Population)
deme <- as.integer(sub("Pop", "", V(g_gravity)$name))

fixtures <- list(
  chain    = case_record(make_chain(), c(0.5, 1, Inf, 0.01)),
  chain_x  = case_record(make_chain(), c(0.5, 1), x = 10:1),
  tree     = case_record(make_chain(extra = list()), c(0.5)),
  disjoint = case_record(g_disjoint, c(0.5, Inf)),
  gravity  = case_record(g_gravity, c(0.5, 1), x = deme)
)
write_json(fixtures, file.path(fixture_dir, "gravity_fixtures.json"),
           auto_unbox = TRUE, digits = 17, pretty = TRUE, na = "null")

# Genotype-level: the gravity genotypes (unique IDs; the dataset's ID column
# repeats) and genetic_distance(mode = "pgd") on them.
locus_cols <- column_class(gravity, "locus")
geno <- data.frame(Population = as.character(gravity$Population),
                   ID = sprintf("I%04d", seq_len(nrow(gravity))),
                   stringsAsFactors = FALSE)
for (col in locus_cols) geno[[col]] <- as.character(gravity[[col]])
write.csv(geno, file.path(pg_fixture_dir, "gravity_genotypes.csv"), row.names = FALSE, na = "", quote = FALSE)

D <- genetic_distance(gravity, stratum = "Population", mode = "pgd")
write_json(list(nodes = rownames(D),
                popgraph_edges = edge_table(g_gravity),
                pgd = row_list(D)),
           file.path(pg_fixture_dir, "gravity_pgd_fixture.json"),
           auto_unbox = TRUE, digits = 17, pretty = TRUE, na = "null")

cat("wrote gravity_fixtures.json and gravity genotype fixtures\n")

# ---------------------------------------------------------------------------
# Seeded tests: msr_null(), source_sink_test(), ibgd().
# ---------------------------------------------------------------------------
W_path <- matrix(0, 6, 6); for (i in 1:5) W_path[i, i + 1] <- W_path[i + 1, i] <- 1
g_chain <- make_chain()

msr_case <- function(z, W, nrepet, seed) {
  set.seed(seed)
  list(z = z, W = row_list(W), nrepet = nrepet, seed = seed,
       replicates = row_list(msr_null(z, W, nrepet = nrepet)))
}

sst_case <- function(g, x, seed, nperm, null = "graph", adjacency = NULL, interior = FALSE) {
  set.seed(seed)
  t <- source_sink_test(g, x = x, nperm = nperm, null = null, adjacency = adjacency,
                        interior = interior, return_null = TRUE)
  rec <- list(x = as.list(setNames(as.numeric(x), V(g)$name)), seed = seed, nperm = nperm,
              null = null, interior = interior,
              statistic = unname(t$statistic), p_value = t$p.value,
              nodes = unname(t$parameter["nodes"]), degree_share = unname(t$estimate),
              r_null = t$r_null)
  if (!is.null(adjacency)) rec$adjacency <- row_list(adjacency)
  rec
}

ibgd_case <- function(g, x, seed, nperm) {
  set.seed(seed)
  rc <- ibgd(g, x = x, nperm = nperm)
  rp <- ibgd(g, x = x, mode = "pgd")
  D <- abs(outer(x, x, "-")); Fw <- outer(x, x, function(a, b) b > a) * 1
  rpd <- ibgd(g, distance = D, forward = Fw, mode = "pgd")
  list(x = as.list(setNames(as.numeric(x), V(g)$name)), seed = seed, nperm = nperm,
       distance = row_list(D), forward = row_list(Fw),
       cgd = list(statistic = unname(rc$statistic), p_value = rc$p.value,
                  pairs = unname(rc$parameter["pairs"]),
                  R2 = unname(rc$estimate["R2"]), slope = unname(rc$estimate["slope"])),
       pgd = list(delta_R2 = unname(rp$statistic), pairs = unname(rp$parameter["pairs"]),
                  R2_cGD = unname(rp$estimate["R2 cGD"]),
                  adj_R2_pGD = unname(rp$estimate["adj R2 pGD"]),
                  forward_slope = unname(rp$estimate["forward slope"]),
                  reverse_slope = unname(rp$estimate["reverse slope"]),
                  slope_ratio = unname(rp$estimate["slope ratio"])),
       pgd_distance_delta_R2 = unname(rpd$statistic))
}

kernel_adjacency <- (as_adjacency_matrix(g_chain, sparse = FALSE) > 0) * 1

tests <- list(
  msr = list(
    path  = msr_case(c(3, 1, 4, 1, 5, 9), W_path, 5, 1),
    chain = msr_case(source_sink_scores(g_chain)$S,
                     { A <- as_adjacency_matrix(g_chain, attr = "weight", sparse = FALSE)
                       bbar <- mean(E(g_chain)$weight)
                       A[A > 0] <- exp(-A[A > 0]^2 / (2 * bbar^2)); A }, 20, 7)
  ),
  source_sink = list(
    chain_graph     = c(list(graph = "chain"), sst_case(g_chain, 1:10, 11, 199)),
    chain_permute   = c(list(graph = "chain"), sst_case(g_chain, 1:10, 12, 199, null = "permute")),
    chain_adjacency = c(list(graph = "chain"), sst_case(g_chain, 1:10, 13, 199, null = "adjacency",
                                                        adjacency = kernel_adjacency)),
    gravity_graph   = c(list(graph = "gravity"), sst_case(g_gravity, deme, 1, 199)),
    gravity_interior = c(list(graph = "gravity"), sst_case(g_gravity, deme, 2, 199, interior = TRUE))
  ),
  ibgd = list(
    chain   = c(list(graph = "chain"), ibgd_case(g_chain, 1:10, 1, 199)),
    gravity = c(list(graph = "gravity"), ibgd_case(g_gravity, deme, 1, 199))
  )
)
write_json(tests, file.path(fixture_dir, "gravity_tests_fixtures.json"),
           auto_unbox = TRUE, digits = 17, pretty = TRUE, na = "null")
cat("wrote gravity_tests_fixtures.json\n")

# locus_subsample_null() on the gravity genotypes (also records which loci were
# drawn, by reproducing the sample() calls with the same seed).
set.seed(31)
lsn <- locus_subsample_null(gravity, stratum = "Population", k = c(2, 4, 8), nsub = 2)
set.seed(31)
fr <- frequencies(gravity[, c("Population", locus_cols)], stratum = "Population")
pbar <- stats::aggregate(Frequency ~ Locus + Allele, data = fr, FUN = mean)
poly <- locus_cols[locus_cols %in% unique(pbar$Locus[pbar$Frequency > 0 & pbar$Frequency < 1])]
drawn <- list(); for (kk in c(2, 4, 8)) for (s in 1:2) drawn[[length(drawn) + 1]] <- sample(poly, kk)
write_json(list(seed = 31, k = c(2, 4, 8), nsub = 2, polymorphic = poly,
                rows = cbind(lsn, loci = I(drawn))),
           file.path(pg_fixture_dir, "gravity_locus_subsample_fixture.json"),
           auto_unbox = TRUE, digits = 17, pretty = TRUE, na = "null")
cat("wrote gravity_locus_subsample_fixture.json\n")
