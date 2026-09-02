#!/usr/bin/env Rscript
# Generates R-reference fixtures for the downstream popgraph operations ported
# into Sources/Graph/Extensions/. Run with gstudio + igraph + jsonlite installed.

suppressPackageStartupMessages({
  library(igraph)
  library(jsonlite)
  library(gstudio)   # requires gstudio >= 1.14 (the "mimic swift package" release)
})
stopifnot(packageVersion("gstudio") >= "1.14")

fixture_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(fixture_dir)) stop("pass the output Fixtures dir as arg 1")

# Build an undirected weighted igraph from an edge list (data.frame from/to/weight)
# preserving row order and orientation.
make_graph <- function(edges, node_names) {
  g <- graph_from_data_frame(edges, directed = FALSE,
                             vertices = data.frame(name = node_names))
  class(g) <- c("popgraph", "igraph")
  g
}

edge_records <- function(g, extra = NULL) {
  el <- as_edgelist(g, names = TRUE)
  df <- data.frame(from = el[, 1], to = el[, 2], stringsAsFactors = FALSE)
  if (!is.null(extra)) df <- cbind(df, extra)
  df
}

asym_indices <- function(g) {
  g2 <- graph_asymmetries(g)
  b <- setNames(V(g2)$bandwidth, V(g2)$name)
  list(
    bandwidth = as.list(b),
    edges = edge_records(g2, data.frame(
      w_away = E(g2)$w_away,
      w_to   = E(g2)$w_to,
      delta  = E(g2)$delta
    ))
  )
}

asym_weights <- function(g) {
  w <- asymmetric_weights(g)
  data.frame(i = w$i, j = w$j, pij = w$pij, pji = w$pji,
             cGD = w$cGD, dij = w$dij, dji = w$dji, delta = w$Delta,
             stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# 1. Real popgraphs, rebuilt from the existing popgraph_<name>_fixture.json so
#    the input graph is bit-identical to what the Swift test constructs.
# ---------------------------------------------------------------------------
pg_fixture_dir <- file.path(fixture_dir, "..", "..",
                            "PopulationGeneticsTests", "Fixtures")

real <- list()
for (name in c("arapat", "cornus")) {
  src <- fromJSON(file.path(pg_fixture_dir, sprintf("popgraph_%s_fixture.json", name)))
  edges <- data.frame(from = as.character(src$edges$from),
                      to   = as.character(src$edges$to),
                      weight = as.numeric(src$edges$weight),
                      stringsAsFactors = FALSE)
  node_names <- as.character(src$nodes$name)
  g <- make_graph(edges, node_names)

  real[[name]] <- list(
    nodes = node_names,
    edges = edges,
    graph_asymmetries = asym_indices(g),
    asymmetric_weights = asym_weights(g),
    asymmetric_popgraph = {
      d <- asymmetric_popgraph(g)
      el <- as_edgelist(d, names = TRUE)
      list(edges = data.frame(from = el[, 1], to = el[, 2],
                              weight = E(d)$weight, stringsAsFactors = FALSE),
           edge_count = ecount(d),
           weight_sum = sum(E(d)$weight))
    }
  )
}
write_json(real, file.path(fixture_dir, "downstream_real.json"),
           auto_unbox = TRUE, digits = 17, pretty = TRUE)

# ---------------------------------------------------------------------------
# 2. Small hand-built graphs mirroring gstudio's own test fixtures.
# ---------------------------------------------------------------------------

# Triangle from test-graph_asymmetries.R: A-B(2), A-C(3), B-C(1)
triangle_edges <- data.frame(
  from = c("A", "A", "B"), to = c("B", "C", "C"),
  weight = c(2, 3, 1), stringsAsFactors = FALSE)
g_tri <- make_graph(triangle_edges, c("A", "B", "C"))

# 4-node from test-asymmetric_weights.R: A-B(0.5), A-C(1.2), B-C(0.8), C-D(0.4)
quad_edges <- data.frame(
  from = c("A", "A", "B", "C"), to = c("B", "C", "C", "D"),
  weight = c(0.5, 1.2, 0.8, 0.4), stringsAsFactors = FALSE)
g_quad <- make_graph(quad_edges, c("A", "B", "C", "D"))

# congruence_topology / test_congruence pair from those test files
A <- matrix(0, 4, 4); B <- matrix(0, 4, 4)
A[1,2] <- A[1,3] <- A[2,3] <- A[3,4] <- 1
B[1,2] <- B[1,3] <- B[1,4] <- B[2,4] <- B[2,3] <- 1
A <- A + t(A); B <- B + t(B)
rownames(A) <- colnames(A) <- rownames(B) <- colnames(B) <- LETTERS[1:4]
g1 <- as.popgraph(A); g2 <- as.popgraph(B)
cong <- congruence_topology(g1, g2)
tc <- test_congruence(g1, g2)

# ops_popgraph: atlas graphs
e1 <- as.popgraph(graph_from_atlas(716))
e2 <- as.popgraph(graph_from_atlas(806))
e3 <- e1 - e2
atlas_edges <- function(g) {
  el <- as_edgelist(g, names = TRUE)
  data.frame(from = el[, 1], to = el[, 2], stringsAsFactors = FALSE)
}

small <- list(
  triangle = list(
    nodes = c("A", "B", "C"), edges = triangle_edges,
    graph_asymmetries = asym_indices(g_tri)
  ),
  quad = list(
    nodes = c("A", "B", "C", "D"), edges = quad_edges,
    graph_asymmetries = asym_indices(g_quad),
    asymmetric_weights = asym_weights(g_quad),
    asymmetric_popgraph = {
      d <- asymmetric_popgraph(g_quad)
      el <- as_edgelist(d, names = TRUE)
      list(edges = data.frame(from = el[, 1], to = el[, 2],
                              weight = E(d)$weight, stringsAsFactors = FALSE),
           edge_count = ecount(d), weight_sum = sum(E(d)$weight))
    }
  ),
  congruence = list(
    graph1_edges = { el <- as_edgelist(g1, names = TRUE)
      data.frame(from = el[,1], to = el[,2], stringsAsFactors = FALSE) },
    graph2_edges = { el <- as_edgelist(g2, names = TRUE)
      data.frame(from = el[,1], to = el[,2], stringsAsFactors = FALSE) },
    graph1_nodes = V(g1)$name, graph2_nodes = V(g2)$name,
    topology_nodes = V(cong)$name,
    topology_edges = atlas_edges(cong),
    topology_node_count = vcount(cong),
    topology_edge_count = ecount(cong),
    test_congruence = list(
      estimate = unname(tc$estimate),
      statistic = unname(tc$statistic),
      df = unname(tc$parameter),
      p_value = unname(tc$p.value)
    )
  ),
  ops_minus = list(
    e1_nodes = V(e1)$name, e1_edges = atlas_edges(e1),
    e2_nodes = V(e2)$name, e2_edges = atlas_edges(e2),
    result_nodes = V(e3)$name, result_edges = atlas_edges(e3),
    result_node_count = vcount(e3), result_edge_count = ecount(e3)
  )
)
write_json(small, file.path(fixture_dir, "downstream_small.json"),
           auto_unbox = TRUE, digits = 17, pretty = TRUE)

# ---------------------------------------------------------------------------
# 3. Seeded resampling ops (Phase 2a). The Swift side uses RMersenneTwister,
#    which reproduces R's set.seed()/sample() bit-for-bit, so every fixture
#    here pins BOTH the input graph and the seed and the Swift test asserts
#    exact identity. C collate so sort(e[,1]) matches Swift's ASCII sort.
# ---------------------------------------------------------------------------
Sys.setlocale("LC_COLLATE", "C")

directed_edge_df <- function(g) {
  el <- as_edgelist(g, names = TRUE)
  data.frame(from = el[, 1], to = el[, 2], stringsAsFactors = FALSE)
}

randomize_case <- function(g, mode, seed) {
  set.seed(seed)
  gr <- randomize_graph(g, mode = mode)
  if (is.null(V(gr)$name)) V(gr)$name <- as.character(seq_len(vcount(gr)))
  list(seed = seed, mode = mode,
       node_names = V(gr)$name,
       edges = directed_edge_df(gr),
       node_count = vcount(gr), edge_count = ecount(gr))
}

sig_table <- function(df) {
  data.frame(from = as.character(df$from), to = as.character(df$to),
             delta = df$delta, statistic = df$statistic,
             p_value = df$p_value, stringsAsFactors = FALSE)
}

# For the seeded ops we build the input graph directly from popgraph() so the
# gstudio paired tests (test-swift-parity.R) can reconstruct the identical graph
# with `data(<name>); popgraph(to_mv(<name>), <name>$Population)`.
graph_edge_df <- function(g) {
  D <- igraph::as_adjacency_matrix(g, attr = "weight", sparse = FALSE)
  el <- igraph::as_edgelist(g, names = TRUE)
  data.frame(from = el[, 1], to = el[, 2],
             weight = vapply(seq_len(nrow(el)), function(i) D[el[i, 1], el[i, 2]], numeric(1)),
             stringsAsFactors = FALSE)
}

resampling <- list()
for (name in c("arapat", "cornus")) {
  dataset <- get(data(list = name, package = "gstudio"))
  g <- popgraph(to_mv(dataset), dataset$Population)
  class(g) <- c("popgraph", "igraph")
  edges <- graph_edge_df(g)

  nperm <- 200
  set.seed(4041); bw  <- asymmetry_bandwidth(g, nperm = nperm)
  set.seed(5051); net <- asymmetry_network(g, nperm = nperm, rewire = "degree")

  # Recompute the network null vector explicitly (same seed/algorithm) so the
  # Swift test can compare the whole distribution, not just the p-value.
  set.seed(5051)
  g_obs <- graph_asymmetries(g); obs_stat <- mean(abs(E(g_obs)$delta))
  w <- E(g)$weight; net_null <- numeric(nperm)
  for (p in seq_len(nperm)) {
    gr <- randomize_graph(g, mode = "degree")
    if (is.null(V(gr)$name)) V(gr)$name <- as.character(seq_len(vcount(gr)))
    ne <- ecount(gr)
    E(gr)$weight <- sample(w, size = ne, replace = (length(w) != ne))
    class(gr) <- c("igraph", "popgraph")
    net_null[p] <- mean(abs(E(graph_asymmetries(gr))$delta))
  }

  resampling[[name]] <- list(
    nodes = V(g)$name,
    edges = edges,
    randomize_degree = randomize_case(g, "degree", 909),
    randomize_full   = randomize_case(g, "full",   919),
    asymmetry_bandwidth = list(seed = 4041, nperm = nperm, rows = sig_table(bw)),
    asymmetry_network   = list(seed = 5051, nperm = nperm, rewire = "degree",
                               delta = net$delta, statistic = net$statistic,
                               p_value = net$p_value, null = net_null)
  )
}

# Small graph for a hand-checkable randomize case (from test-randomize_graph.R style)
set.seed(77)
sx <- sample(c(rep(1, 8), rep(0, 7)), size = 15, replace = FALSE)
SA <- matrix(0, 6, 6); SA[lower.tri(SA)] <- sx; SA <- SA + t(SA)
rownames(SA) <- colnames(SA) <- LETTERS[1:6]
sg <- as.popgraph(SA)
sg_edges <- directed_edge_df(sg)

resampling$small <- list(
  node_names = V(sg)$name,
  edges = sg_edges,
  randomize_degree = randomize_case(sg, "degree", 11),
  randomize_full   = randomize_case(sg, "full",   13)
)

write_json(resampling, file.path(fixture_dir, "downstream_resampling.json"),
           auto_unbox = TRUE, digits = 17, pretty = TRUE)

cat("wrote downstream_{real,small,resampling}.json to", fixture_dir, "\n")
