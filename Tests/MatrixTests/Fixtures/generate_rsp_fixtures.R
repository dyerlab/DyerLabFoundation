#!/usr/bin/env Rscript
# Generates fixtures for the randomized-shortest-path (RSP) distances in Sources/Matrix/Resistance/:
# small resistance landscapes, their sites, and gdistance's distances between them. Run with gdistance (which
# brings raster), terra and jsonlite:
#
#   Rscript generate_rsp_fixtures.R Tests/MatrixTests/Fixtures
#
# The cell graph is built the way a gdistance user would build it:
#
#   tr <- transition(resistance, function(x) 1 / mean(x), directions = 8)   # conductance = 1 / mean resistance
#   tr <- geoCorrection(tr, type = "c")                                      # divide by centre-to-centre metres
#
# so each step costs (r_i + r_j) / 2 times its ground length, and the reference random walk moves in
# proportion to conductance. Those are the `.conductance` cases, compared with stock rSPDistance() and
# costDistance().
#
# The `.areaCorrected` cases keep the type "c" costs but take the reference walk from geoCorrection(type = "r"),
# which also multiplies the conductance of every step between rows by cos(mean latitude). That is the correct
# discrete diffusion on a longitude/latitude grid. Stock gdistance can't do this: with type "r" its costs
# (1 / conductance) are stretched by 1 / cos(latitude) too. So those cases use rsp(), a copy of gdistance's
# internal .rSPDist() that takes the costs and the reference walk separately. rsp() is checked against stock
# rSPDistance() on every `.conductance` case before anything is written.
#
# rsp() also returns the free-energy distance, −log(z_ij) / θ (Kivimäki et al. 2014), from the same solves.
# θ = 0 is included: rSPDistance() then gives the reference walk's expected cost of reaching the target.

suppressPackageStartupMessages({
  library(gdistance)
  library(terra)
  library(jsonlite)
})

fixture_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(fixture_dir)) stop("pass the output Fixtures dir as arg 1")

# gdistance's .rSPDist(), with costs from `trCost` and the reference walk from `trWalk`. Returns the expected
# cost of passage (total and net) and the free-energy distance.
rsp <- function(trCost, trWalk, ci, cj, theta) {
  cost <- trCost
  cost@x <- 1 / cost@x
  nr <- dim(trCost)[1]
  Id <- Matrix::Diagonal(nr)
  P <- gdistance:::.normalize(trWalk, "row")
  W <- cost
  W@x <- exp(-theta * cost@x)
  W <- W * P
  total <- net <- free <- matrix(0, length(ci), length(cj))
  for (j in seq_along(cj)) {
    Ij <- Matrix::Diagonal(nr)
    Ij[cj[j], cj[j]] <- 0
    Wj <- Ij %*% W
    A <- methods::as(Id - Wj, "dgCMatrix")
    ej <- rep(0, nr)
    ej[cj[j]] <- 1
    zcj <- solve(A, ej)
    for (i in seq_along(ci)) {
      ei <- rep(0, nr)
      ei[ci[i]] <- 1
      zci <- solve(t(A), ei)
      zcij <- sum(ei * zcj)
      N <- (Matrix::Diagonal(nr, as.vector(zci)) %*% Wj %*% Matrix::Diagonal(nr, as.vector(zcj))) / zcij
      total[i, j] <- sum(cost * N)
      Nnet <- Matrix::skewpart(N) * 2
      Nnet@x[Nnet@x < 0] <- 0
      net[i, j] <- sum(cost * Nnet)
      free[i, j] <- if (theta > 0) -log(zcij) / theta else NA
    }
  }
  list(total = total, net = net, free = free)
}

# A resistance surface: a gentle gradient, a high-resistance ridge with one gap, and an impassable hole. The
# values are multiples of 1/8 so that Swift's Float32 raster holds exactly the doubles R uses.
landscape <- function(rows, cols) {
  v <- outer(seq_len(rows), seq_len(cols), function(r, c) 1 + 0.125 * r + 0.25 * c)
  ridge <- ceiling(cols / 2)
  v[, ridge] <- 12
  v[rows - 1, ridge] <- 1.5
  v[2:3, 2] <- NA
  as.vector(t(v))            # row-major, north row first
}

specs <- list(
  list(id = "utm_queen", crs = "EPSG:32612", rows = 7, cols = 9, west = 450000, north = 3210000, res = 100,
       directions = 8, thetas = c(0, 1e-4, 1e-3, 3e-3, 1e-2)),
  list(id = "utm_rook", crs = "EPSG:32612", rows = 7, cols = 9, west = 450000, north = 3210000, res = 100,
       directions = 4, thetas = c(0, 1e-3, 1e-2)),
  list(id = "lonlat_30n", crs = "EPSG:4326", rows = 8, cols = 10, west = -111.2, north = 30.05, res = 0.01,
       directions = 8, thetas = c(0, 1e-4, 1e-3, 3e-3)),
  list(id = "lonlat_60n", crs = "EPSG:4326", rows = 8, cols = 10, west = -150.3, north = 60.05, res = 0.01,
       directions = 8, thetas = c(0, 1e-3))
)

# Sites at cell centres, as (row, col) counted from 1 at the north-west corner.
site_cells <- list(c(1, 1), c(7, 2), c(4, 9), c(1, 8))

cases <- lapply(specs, function(spec) {
  values <- landscape(spec$rows, spec$cols)
  ext <- c(spec$west, spec$west + spec$cols * spec$res, spec$north - spec$rows * spec$res, spec$north)
  r <- terra::rast(nrows = spec$rows, ncols = spec$cols, extent = terra::ext(ext), crs = spec$crs)
  terra::values(r) <- values
  rr <- raster::raster(r)

  cells <- sapply(site_cells, function(rc) (rc[1] - 1) * spec$cols + rc[2])
  xy <- terra::xyFromCell(r, cells)
  lonlat <- if (terra::is.lonlat(r)) xy else terra::project(xy, from = spec$crs, to = "EPSG:4326")

  tr <- transition(rr, transitionFunction = function(x) 1 / mean(x), directions = spec$directions)
  trC <- geoCorrection(tr, type = "c")
  trR <- geoCorrection(tr, type = "r")
  ci <- match(cells, transitionCells(trC))
  least <- as.matrix(costDistance(trC, xy, xy))
  mC <- transitionMatrix(trC, inflate = FALSE)
  mR <- transitionMatrix(trR, inflate = FALSE)
  stopifnot(identical(transitionCells(trC), transitionCells(trR)))

  by_theta <- lapply(spec$thetas, function(theta) {
    stock_total <- rSPDistance(trC, xy, xy, theta = theta, totalNet = "total")
    stock_net <- rSPDistance(trC, xy, xy, theta = theta, totalNet = "net")
    mine <- rsp(mC, mC, ci, ci, theta)
    stopifnot(isTRUE(all.equal(mine$total, stock_total, tolerance = 1e-10)),
              isTRUE(all.equal(mine$net, stock_net, tolerance = 1e-10)))
    area <- rsp(mC, mR, ci, ci, theta)
    list(theta = theta,
         conductance = list(total = stock_total, net = stock_net, free = mine$free),
         areaCorrected = list(total = area$total, net = area$net, free = area$free))
  })

  # Every step's cost, as (from, to, cost) with cells numbered from 0, row-major, north row first.
  cost <- methods::as(mC, "TsparseMatrix")
  tc <- transitionCells(trC) - 1
  keep <- tc[cost@i + 1] < tc[cost@j + 1]
  steps <- lapply(which(keep), function(k) c(tc[cost@i[k] + 1], tc[cost@j[k] + 1], 1 / cost@x[k]))

  list(id = spec$id, crs = spec$crs, rows = spec$rows, cols = spec$cols,
       extent = list(west = ext[1], east = ext[2], south = ext[3], north = ext[4]),
       directions = spec$directions,
       values = ifelse(is.na(values), NA, values),
       sites = lapply(seq_along(cells), function(i) list(longitude = lonlat[i, 1], latitude = lonlat[i, 2])),
       steps = steps,
       leastCost = least,
       thetas = by_theta)
})

write_json(list(gdistance = as.character(packageVersion("gdistance")), cases = cases),
           file.path(fixture_dir, "rsp_fixtures.json"), auto_unbox = TRUE, digits = NA, pretty = FALSE,
           na = "null", matrix = "rowmajor")
cat("wrote", length(cases), "RSP cases\n")
