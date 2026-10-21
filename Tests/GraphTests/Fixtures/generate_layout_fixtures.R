#!/usr/bin/env Rscript
# Generates R-reference fixtures for the Kamada-Kawai layout port
# (Sources/Graph/Layout/Core/KamadaKawai.swift <- igraph::layout_with_kk()).
# Run with gstudio + igraph + jsonlite installed:
#   Rscript generate_layout_fixtures.R Tests/GraphTests/Fixtures

suppressPackageStartupMessages({
  library(igraph)
  library(jsonlite)
  library(gstudio)
})

fixture_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(fixture_dir)) stop("pass the output Fixtures dir as arg 1")

make_graph <- function(edges, node_names) {
  graph_from_data_frame(edges, directed = FALSE,
                        vertices = data.frame(name = node_names))
}

# `early_*` is the layout after only 100 moves. Swift and R agree to rounding
# for that long; on graphs whose layout is still moving at 50·n moves (arapat),
# one-ulp differences (C's fused multiply-adds) later steer the greedy
# max-gradient node choice onto a different but equally good path.
record <- function(g, edges, weighting, xy, w = NULL) {
  early <- layout_with_kk(g, maxiter = 100, weights = if (is.null(w)) NA else w)
  list(nodes = V(g)$name, edges = edges, weighting = weighting,
       x = xy[, 1], y = xy[, 2], early_x = early[, 1], early_y = early[, 2])
}

cases <- list()

# Unweighted ring: hop-count distances, circle start is already near equilibrium.
ring <- data.frame(from = c("A", "B", "C", "D", "E", "F"),
                   to   = c("B", "C", "D", "E", "F", "A"),
                   stringsAsFactors = FALSE)
g <- make_graph(ring, LETTERS[1:6])
cases$ring <- record(g, ring, "unweighted", layout_with_kk(g))

# Weighted graph with a second component, exercising the max-distance fill.
split <- data.frame(from = c("A", "B", "A", "C", "E", "D"),
                    to   = c("B", "C", "C", "D", "F", "B"),
                    weight = c(2, 1, 3, 0.5, 1, 4),
                    stringsAsFactors = FALSE)
g <- make_graph(split, LETTERS[1:6])
cases$split <- record(g, split, "edgeWeights", layout_with_kk(g, weights = E(g)$weight),
                      w = E(g)$weight)

# Real popgraphs through gstudio's own layout = "kk" (median-floored weights).
pg_fixture_dir <- file.path(fixture_dir, "..", "..", "PopulationGeneticsTests", "Fixtures")
kk <- gstudio:::.layout_function("kk")
for (name in c("arapat", "cornus")) {
  src <- fromJSON(file.path(pg_fixture_dir, sprintf("popgraph_%s_fixture.json", name)))
  edges <- data.frame(from = as.character(src$edges$from),
                      to   = as.character(src$edges$to),
                      weight = as.numeric(src$edges$weight),
                      stringsAsFactors = FALSE)
  g <- make_graph(edges, as.character(src$nodes$name))
  w <- E(g)$weight
  cases[[name]] <- record(g, edges, "flooredEdgeWeights", kk(g), w = w + 0.25 * median(w))
}

write_json(cases, file.path(fixture_dir, "layout_fixtures.json"),
           auto_unbox = TRUE, digits = 17, pretty = TRUE)
