# Generates distance_fixtures.json for DistanceFixtureTests.
#
# Great-circle distances come from gstudio::strata_distance(mode = "Circle"): the haversine formula on a sphere of
# radius 6371 km. Strata sit where gstudio::strata_coordinates() puts them, at the mean of each stratum's distinct
# coordinates, in the order the strata first appear. Individuals are located by giving each its own stratum.
#
# Genetic distances come from gstudio::genetic_distance(): mode "amova" and "bray" among individuals, and "nei",
# "cavalli", "dps", "euclidean" and "cgd" among Population strata. gstudio fills a missing genotype with zeros, which
# the Swift code doesn't (each locus uses only the units genotyped there), so they are computed on the arapat
# individuals genotyped at every locus, where the two agree. cGD uses the populations with at least 3 of them, as the
# population graph needs. gstudio has no pairwise Phi_ST, so it is the two-stratum AMOVA (Excoffier et al. 1992) of
# each pair, from dist_amova summed over loci, as generate_structure_fixtures.R computes the multilocus AMOVA.
#
# Isolation by distance is vegan::mantel() (which MantelAnalysis ports, permutations included) of a genetic matrix
# against great-circle distance among the same complete-data units, with lm() for the regression line: Rousset's
# Phi_ST / (1 - Phi_ST) against ln km among populations (Pearson), Nei's distance against km (Spearman), and
# Bray-Curtis among the complete individuals against km (Pearson).
#
# Both datasets are the package's own example CSVs, so R and Swift read the same coordinates. For the Cornus
# parent/offspring data only the mothers (OffID 0) are used, as the Distance page does.
#
# Run from this directory:  Rscript generate_distance_fixtures.R

suppressPackageStartupMessages({
  library(gstudio)
  library(popgraph)
  library(vegan)
  library(jsonlite)
})

data_dir <- "../../../Sources/PopulationGenetics/ExampleData"
arapat <- read.csv(file.path(data_dir, "arapat.csv"), stringsAsFactors = FALSE, colClasses = "character")
arapat$Latitude <- as.numeric(arapat$Latitude)
arapat$Longitude <- as.numeric(arapat$Longitude)
cornus <- read.csv(file.path(data_dir, "cornus.csv"), stringsAsFactors = FALSE, colClasses = "character")
cornus$Latitude <- as.numeric(cornus$Latitude)
cornus$Longitude <- as.numeric(cornus$Longitude)

matrix_fixture <- function(df, stratum) {
  coords <- strata_coordinates(df, stratum = stratum)
  d <- strata_distance(coords, mode = "Circle")
  list(names = as.character(coords$Stratum),
       longitude = coords$Longitude,
       latitude = coords$Latitude,
       values = unname(as.vector(t(d))))
}

first_individuals <- arapat[1:30, ]
mothers <- cornus[cornus$OffID == "0", ]

# ---- Genetic distances, on the complete-data individuals ----------------------------------------------------------

loci <- names(arapat)[7:ncol(arapat)]
complete <- arapat[apply(arapat[, loci], 1, function(row) all(row != "")), ]
genotypes <- complete[, c("Population", "ID")]
for (l in loci) genotypes[[l]] <- locus(complete[[l]], type = "separated")

genetic_fixture <- function(d, names) {
  d <- as.matrix(d)
  list(names = names, values = unname(as.vector(t(d))))
}

first_complete <- genotypes[1:30, ]
amova_distance <- Reduce(`+`, lapply(loci, function(l) as.matrix(gstudio:::dist_amova(genotypes[, c("Population", l)]))))

pairwise_phi <- function(D, g) {
  strata <- unique(g)
  K <- length(strata)
  phi <- matrix(0, K, K)
  for (a in 1:(K - 1)) for (b in (a + 1):K) {
    i <- which(g %in% strata[c(a, b)])
    d <- D[i, i]
    h <- g[i]
    N <- length(i)
    n <- as.numeric(table(factor(h, levels = strata[c(a, b)])))
    ssTotal <- sum(d[upper.tri(d)]) / N
    ssWithin <- sum(sapply(strata[c(a, b)], function(k) {
      j <- which(h == k)
      e <- d[j, j, drop = FALSE]
      sum(e[upper.tri(e)]) / length(j)
    }))
    n0 <- (N - sum(n^2) / N)
    sigmaWithin <- ssWithin / (N - 2)
    sigmaAmong <- ((ssTotal - ssWithin) - sigmaWithin) / n0
    phi[a, b] <- phi[b, a] <- sigmaAmong / (sigmaAmong + sigmaWithin)
  }
  phi
}

population_order <- unique(genotypes$Population)
reorder <- function(d) as.matrix(d)[population_order, population_order]
graph_populations <- names(which(table(genotypes$Population) >= 3))
graph_genotypes <- genotypes[genotypes$Population %in% graph_populations, ]
graph_order <- unique(graph_genotypes$Population)
cgd <- as.matrix(genetic_distance(graph_genotypes, stratum = "Population", mode = "cgd"))[graph_order, graph_order]

genetic <- list(
  completeIndividuals = complete$ID,
  amovaFirst30 = genetic_fixture(amova_distance[1:30, 1:30], first_complete$ID),
  # mode "bray" numbers the individuals 1..n as strata, which come back sorted as text ("1", "10", "11", ...).
  brayFirst30 = genetic_fixture(as.matrix(genetic_distance(first_complete, mode = "bray"))[as.character(1:30),
                                                                                          as.character(1:30)],
                                first_complete$ID),
  nei = genetic_fixture(reorder(genetic_distance(genotypes, stratum = "Population", mode = "nei")), population_order),
  cavalli = genetic_fixture(reorder(genetic_distance(genotypes, stratum = "Population", mode = "cavalli")),
                            population_order),
  dps = genetic_fixture(reorder(genetic_distance(genotypes, stratum = "Population", mode = "dps")), population_order),
  euclidean = genetic_fixture(reorder(genetic_distance(genotypes, stratum = "Population", mode = "euclidean")),
                              population_order),
  phiST = genetic_fixture(pairwise_phi(amova_distance, genotypes$Population), population_order),
  cgd = genetic_fixture(cgd, graph_order)
)

# ---- Isolation by distance -----------------------------------------------------------------------------------------

km_among <- function(df, stratum, order) {
  coords <- strata_coordinates(df, stratum = stratum)
  d <- as.matrix(strata_distance(coords, mode = "Circle"))
  dimnames(d) <- list(as.character(coords$Stratum), as.character(coords$Stratum))
  d[order, order]
}

ibd_case <- function(genetic, km, method, seed, permutations = 99) {
  set.seed(seed)
  m <- mantel(as.dist(km), as.dist(genetic), method = method, permutations = permutations)
  pairs <- lower.tri(genetic)
  fit <- lm(genetic[pairs] ~ km[pairs])
  list(method = method, seed = seed, permutations = permutations, r = unname(m$statistic), p = m$signif,
       intercept = unname(coef(fit)[1]), slope = unname(coef(fit)[2]), r2 = summary(fit)$r.squared,
       pairs = sum(pairs))
}

phi <- pairwise_phi(amova_distance, genotypes$Population)
dimnames(phi) <- list(population_order, population_order)
population_km <- km_among(complete, "Population", population_order)
nei_matrix <- reorder(genetic_distance(genotypes, stratum = "Population", mode = "nei"))
individual_km <- km_among(complete, "ID", complete$ID)
bray_all <- as.matrix(genetic_distance(genotypes, mode = "bray"))[as.character(seq_len(nrow(genotypes))),
                                                                  as.character(seq_len(nrow(genotypes)))]

ibd <- list(
  rousset = ibd_case(phi / (1 - phi), log(population_km), "pearson", 42),
  nei = ibd_case(nei_matrix, population_km, "spearman", 7),
  bray = ibd_case(bray_all, individual_km, "pearson", 2026)
)

fixtures <- list(
  earthRadius = 6371,
  arapatPopulation = matrix_fixture(arapat, "Population"),
  arapatSpecies = matrix_fixture(arapat, "Species"),
  arapatCluster = matrix_fixture(arapat, "Cluster"),
  arapatFirst30Individuals = matrix_fixture(first_individuals, "ID"),
  cornusMothers = matrix_fixture(mothers, "ID"),
  genetic = genetic,
  ibd = ibd
)

write(toJSON(fixtures, digits = NA, auto_unbox = TRUE, pretty = TRUE), "distance_fixtures.json")
cat("Wrote distance_fixtures.json:",
    length(fixtures$arapatPopulation$names), "populations,",
    length(fixtures$cornusMothers$names), "Cornus mothers,",
    nrow(complete), "complete arapat individuals\n")
