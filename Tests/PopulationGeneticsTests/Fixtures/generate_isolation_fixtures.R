# Generates isolation_fixtures.json for IsolationFixtureTests: gstudio's genetic_isolation() from genotypes, which
# IBDAnalysis ports, and genetic_distance(mode = "dcGD"), which DistanceAnalysis ports.
#
#   - mode = "IBGD": a Population Graph among the strata, then ibgd(mode = "cGD"), the Mantel test of conditional
#     genetic distance on separation (one-sided, permuting positions).
#   - mode = "dcGD": the same graph, then ibgd(mode = "dcGD"): directional conditional genetic distance regressed on
#     separation with forward and reverse slopes, and Delta R2 = adj R2 dcGD - R2 cGD. No p-value.
#
# Two datasets:
#   - gravity (gstudio's bundled simulation; Fixtures/gravity_genotypes.csv, written by
#     Tests/GraphTests/Fixtures/generate_gravity_fixtures.R): 25 demes on a stepping stone, with the deme number as the
#     axis (a named vector), so separation is |deme_j - deme_i| and forward runs toward higher demes.
#   - arapat, the individuals genotyped at every locus in the populations with at least 3 of them (as
#     generate_distance_fixtures.R uses for cGD): separation by great-circle distance (km), or along axis = "Latitude",
#     which genetic_isolation() averages over each population's individuals; and dcGD with spatial = the great-circle
#     matrix and axis = "Latitude", where the axis only sets the direction.
#
# Run from this directory:  Rscript generate_isolation_fixtures.R
# Needs gstudio (>= 1.15.7, for dcgd() and mode = "dcGD") and jsonlite.

suppressPackageStartupMessages({
  library(gstudio)
  library(jsonlite)
})
stopifnot(packageVersion("gstudio") >= "1.15.7")

nperm <- 99L

ibgd_record <- function(res) {
  list(r = unname(res$statistic), p = res$p.value, pairs = unname(res$parameter["pairs"]),
       r2 = unname(res$estimate["R2"]), slope = unname(res$estimate["slope"]))
}

dcgd_record <- function(res) {
  list(delta_R2 = unname(res$statistic), pairs = unname(res$parameter["pairs"]),
       R2_cGD = unname(res$estimate["R2 cGD"]), adj_R2_dcGD = unname(res$estimate["adj R2 dcGD"]),
       forward_slope = unname(res$estimate["forward slope"]),
       reverse_slope = unname(res$estimate["reverse slope"]),
       slope_ratio = unname(res$estimate["slope ratio"]))
}

matrix_record <- function(d, order) {
  d <- as.matrix(d)[order, order]
  list(names = order, values = unname(as.vector(t(d))))
}

# ---- gravity, along the deme axis ---------------------------------------------------------------------------------

geno <- read.csv("gravity_genotypes.csv", stringsAsFactors = FALSE, colClasses = "character")
for (l in setdiff(names(geno), c("Population", "ID"))) geno[[l]] <- locus(geno[[l]], type = "separated")
pops <- unique(geno$Population)
deme <- setNames(as.numeric(sub("Pop", "", pops)), pops)

seed <- 20261121
set.seed(seed)
gravity_ibgd <- genetic_isolation(geno, mode = "IBGD", axis = deme, nperm = nperm)
gravity_dcgd <- genetic_isolation(geno, mode = "dcGD", axis = deme)
# A scrambled axis, whose weak association gives a P the permutations decide, so P checks them draw for draw.
scrambled <- setNames(c(2, 11, 15, 24, 9, 7, 19, 3, 6, 10, 23, 5, 12, 16, 14, 21, 17, 4, 18, 25, 22, 13, 8, 1, 20),
                      pops)
set.seed(seed)
gravity_scrambled <- genetic_isolation(geno, mode = "IBGD", axis = scrambled, nperm = nperm)
gravity_scrambled_dcgd <- genetic_isolation(geno, mode = "dcGD", axis = scrambled)
gravity <- list(seed = seed, nperm = nperm, axis = as.list(deme), scrambled_axis = as.list(scrambled),
                ibgd = ibgd_record(gravity_ibgd), dcgd = dcgd_record(gravity_dcgd),
                scrambled_ibgd = ibgd_record(gravity_scrambled), scrambled_dcgd = dcgd_record(gravity_scrambled_dcgd))

# ---- arapat, great-circle distance and latitude --------------------------------------------------------------------

arapat <- read.csv("../../../Sources/PopulationGenetics/ExampleData/arapat.csv", stringsAsFactors = FALSE,
                   colClasses = "character")
arapat$Latitude <- as.numeric(arapat$Latitude)
arapat$Longitude <- as.numeric(arapat$Longitude)
loci <- names(arapat)[7:ncol(arapat)]
complete <- arapat[apply(arapat[, loci], 1, function(row) all(row != "")), ]
complete <- complete[complete$Population %in% names(which(table(complete$Population) >= 3)), ]
x <- complete[, c("Population", "ID", "Latitude", "Longitude")]
for (l in loci) x[[l]] <- locus(complete[[l]], type = "separated")
order <- unique(x$Population)

km <- strata_distance(strata_coordinates(x, stratum = "Population"), mode = "Circle")
km <- as.matrix(km)[order, order]

set.seed(seed)
arapat_ibgd <- genetic_isolation(x, mode = "IBGD", nperm = nperm)
set.seed(seed)
arapat_ibgd_latitude <- genetic_isolation(x, mode = "IBGD", axis = "Latitude", nperm = nperm)
arapat_dcgd_latitude <- genetic_isolation(x, mode = "dcGD", axis = "Latitude")
set.seed(seed)
arapat_ibgd_longitude <- genetic_isolation(x, mode = "IBGD", axis = "Longitude", nperm = nperm)
arapat_dcgd_km <- genetic_isolation(x, mode = "dcGD", axis = "Latitude", spatial = km)

arapat_fixture <- list(
  seed = seed, nperm = nperm,
  ibgd = ibgd_record(arapat_ibgd),
  ibgd_latitude = ibgd_record(arapat_ibgd_latitude),
  ibgd_longitude = ibgd_record(arapat_ibgd_longitude),
  dcgd_latitude = dcgd_record(arapat_dcgd_latitude),
  dcgd_km = dcgd_record(arapat_dcgd_km),
  dcgd_matrix = matrix_record(genetic_distance(x, stratum = "Population", mode = "dcGD"), order)
)

write_json(list(gravity = gravity, arapat = arapat_fixture), "isolation_fixtures.json",
           auto_unbox = TRUE, digits = NA, pretty = TRUE)
cat("wrote isolation_fixtures.json\n")
