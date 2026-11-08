# Generates structure_fixtures.json for StructureFixtureTests.
#
# Weir & Cockerham's theta is computed as the nested analysis of variance of allele indicators in Weir (1996,
# Genetic Data Analysis II, ch. 5): among strata, among individuals within strata, and within individuals, summed
# over alleles. Each locus uses only the individuals genotyped at it. hierfstat::wc() is computed alongside as an
# independent check, and the script stops if the two disagree.
#
# The multilocus AMOVA (Excoffier, Smouse & Quattro 1992) uses gstudio's Smouse-Peakall squared distances
# (gstudio:::dist_amova) summed over loci, on the individuals genotyped at every locus, so no missing-data rule is
# involved.
#
# The allele-count AMOVAs are computed per locus from the individuals genotyped there, without a distance matrix:
# gene copies (each allele copy a unit, two per individual; squared distance 1 between different alleles) and
# genotypes (Smouse-Peakall squared distances, as gstudio:::dist_amova gives them, checked against it). With
# delta^2 the squared distance, SS = sum over pairs within a group of delta^2, over the group's size. The
# multilocus value is a ratio of sums: sum of sigma^2 among over the sum of sigma^2 total, never a mean of the
# per-locus values. On the complete-data individuals, the genotype version must equal the summed-distance AMOVA.
#
# Hs and Ht come from three estimators, with n the harmonic mean of the strata sizes, k the number of strata
# genotyped, pbar the unweighted mean of the strata frequencies and Ho the mean observed heterozygosity:
# - Jost (2008, eq. 12), checked per locus against mmod ("differentiation"):
#   Hs = 2n/(2n - 1) mean_i(1 - sum_u p_iu^2), Ht = 1 - sum_u pbar_u^2 + Hs/(2kn);
# - Nei & Chesser (1983), checked per locus against hierfstat::basic.stats ("differentiationNeiChesser"):
#   Hs = n/(n - 1) (mean_i(1 - sum_u p_iu^2) - Ho/(2n)), Ht = 1 - sum_u pbar_u^2 + Hs/(kn) - Ho/(2kn);
# - Nei (1973), uncorrected ("differentiationUncorrected"): Hs = mean_i(1 - sum_u p_iu^2), Ht = 1 - sum_u pbar_u^2.
# Gst =
# (Ht - Hs)/Ht, G'st = Gst (k - 1 + Hs)/((k - 1)(1 - Hs)) (Hedrick 2005) and Dest = (Ht - Hs)/(1 - Hs) k/(k - 1)
# (Jost 2008). Multilocus, as ratios of sums: Gst = sum(Ht - Hs)/sum(Ht), G'st = sum((Ht - Hs)(k - 1 + Hs)) /
# sum(Ht (k - 1)(1 - Hs)), Dest = sum((Ht - Hs) k/(k - 1))/sum(1 - Hs).
#
# Run from this directory: Rscript generate_structure_fixtures.R
# Needs gstudio, hierfstat, adegenet, mmod and jsonlite.

suppressMessages({
  library(gstudio)
  library(hierfstat)
  library(jsonlite)
  library(adegenet)
  library(mmod)
})

raw <- read.csv("arapat_genotypes.csv", colClasses = "character")
loci <- names(raw)[3:ncol(raw)]

# ---- Weir & Cockerham -------------------------------------------------------------------------------------------

weir_cockerham <- function(geno, pop) {
  ok <- geno != "" & grepl(":", geno)
  geno <- geno[ok]
  pop <- factor(pop[ok])
  al <- strsplit(geno, ":")
  alleles <- sort(unique(unlist(al)))
  n <- as.numeric(table(pop))
  r <- length(n)
  N <- sum(n)
  nc <- (N - sum(n^2) / N) / (r - 1)
  ms <- c(among = 0, individuals = 0, within = 0)
  for (u in alleles) {
    x <- t(sapply(al, function(g) as.numeric(g == u)))
    p <- tapply(rowSums(x) / 2, pop, mean)
    h <- tapply(x[, 1] != x[, 2], pop, mean)
    pbar <- sum(n * p) / N
    ms <- ms + c(sum(2 * n * (p - pbar)^2) / (r - 1),
                 sum(n * (2 * p * (1 - p) - h / 2)) / (N - r),
                 sum(n * h) / (2 * N))
  }
  a <- (ms[["among"]] - ms[["individuals"]]) / (2 * nc)
  b <- (ms[["individuals"]] - ms[["within"]]) / 2
  c <- ms[["within"]]
  df <- c(r - 1, N - r, N)
  ss <- ms * df
  list(locus = NA, individuals = N, strata = r, nc = nc,
       sigmaAmong = a, sigmaIndividuals = b, sigmaWithin = c,
       theta = a / (a + b + c), fIS = b / (b + c), fIT = (a + b) / (a + b + c),
       df = unname(c(df, 2 * N - 1)), ss = unname(c(ss, sum(ss))), ms = unname(ms))
}

wc <- lapply(loci, function(l) {
  res <- weir_cockerham(raw[[l]], raw$Population)
  res$locus <- l
  keep <- raw[[l]] != ""
  al <- strsplit(raw[[l]][keep], ":")
  codes <- sort(unique(unlist(al)))
  g <- as.integer(sapply(al, function(p) paste0(sprintf("%02d", match(p[1], codes)),
                                                sprintf("%02d", match(p[2], codes)))))
  h <- hierfstat::wc(data.frame(pop = as.integer(factor(raw$Population[keep])), g), diploid = TRUE)
  stopifnot(abs(h$FST - res$theta) < 1e-10, abs(h$FIS - res$fIS) < 1e-10)
  res
})

# ---- Multilocus AMOVA -------------------------------------------------------------------------------------------

complete <- which(apply(raw[, loci], 1, function(row) all(row != "")))
x <- data.frame(Population = raw$Population[complete])
for (l in loci) x[[l]] <- locus(raw[[l]][complete], type = "separated")
D <- Reduce(`+`, lapply(loci, function(l) as.matrix(gstudio:::dist_amova(x[, c("Population", l)]))))

g <- factor(x$Population)
N <- length(g)
K <- nlevels(g)
n <- as.numeric(table(g))
ssTotal <- sum(D[upper.tri(D)]) / N
ssWithin <- sum(sapply(levels(g), function(k) {
  i <- which(g == k)
  d <- D[i, i, drop = FALSE]
  sum(d[upper.tri(d)]) / length(i)
}))
n0 <- (N - sum(n^2) / N) / (K - 1)
sigmaWithin <- ssWithin / (N - K)
sigmaAmong <- ((ssTotal - ssWithin) / (K - 1) - sigmaWithin) / n0
amova <- list(loci = loci, individuals = raw$ID[complete],
              dfAmong = K - 1, dfWithin = N - K,
              ssAmong = ssTotal - ssWithin, ssWithin = ssWithin, ssTotal = ssTotal,
              sigmaAmong = sigmaAmong, sigmaWithin = sigmaWithin,
              phiST = sigmaAmong / (sigmaAmong + sigmaWithin))

# ---- Multilocus Weir & Cockerham ----------------------------------------------------------------------------------

sums <- Reduce(`+`, lapply(wc, function(r) c(r$sigmaAmong, r$sigmaIndividuals, r$sigmaWithin)))
wcMultilocus <- list(theta = sums[1] / sum(sums), fIS = sums[2] / (sums[2] + sums[3]),
                     fIT = (sums[1] + sums[2]) / sum(sums))
all_codes <- lapply(loci, function(l) sort(unique(unlist(strsplit(raw[[l]][raw[[l]] != ""], ":")))))
hdat <- data.frame(pop = as.integer(factor(raw$Population)))
for (j in seq_along(loci)) {
  g <- raw[[loci[j]]]
  hdat[[loci[j]]] <- sapply(strsplit(g, ":"), function(p) {
    if (length(p) < 2) NA else as.integer(paste0(sprintf("%02d", match(p[1], all_codes[[j]])),
                                                 sprintf("%02d", match(p[2], all_codes[[j]]))))
  })
}
hw <- hierfstat::wc(hdat, diploid = TRUE)
stopifnot(abs(hw$FST - wcMultilocus$theta) < 1e-10, abs(hw$FIS - wcMultilocus$fIS) < 1e-10)

# ---- Allele-count AMOVA per locus ---------------------------------------------------------------------------------

two_level <- function(ss_total, ss_within, sizes) {
  r <- length(sizes)
  M <- sum(sizes)
  n0 <- (M - sum(sizes^2) / M) / (r - 1)
  sw <- ss_within / (M - r)
  sa <- ((ss_total - ss_within) / (r - 1) - sw) / n0
  list(units = M, strata = r, dfAmong = r - 1, dfWithin = M - r, ssAmong = ss_total - ss_within,
       ssWithin = ss_within, ssTotal = ss_total, sigmaAmong = sa, sigmaWithin = sw, phiST = sa / (sa + sw))
}

# Pairs of different allele copies among m copies with allele counts cnt: (m^2 - sum cnt^2)/2.
copy_ss <- function(copies) {
  cnt <- table(copies)
  (length(copies)^2 - sum(cnt^2)) / 2 / length(copies)
}

dist_ss <- function(D) sum(D[upper.tri(D)]) / nrow(D)

amova_locus <- lapply(loci, function(l) {
  keep <- raw[[l]] != ""
  pop <- raw$Population[keep]
  al <- strsplit(raw[[l]][keep], ":")
  copies <- unlist(al)
  copyPop <- rep(pop, each = 2)
  geneCopies <- two_level(copy_ss(copies),
                          sum(sapply(unique(pop), function(k) copy_ss(copies[copyPop == k]))),
                          as.numeric(table(copyPop)))

  codes <- sort(unique(copies))
  counts <- t(sapply(al, function(p) tabulate(match(p, codes), length(codes))))
  D <- as.matrix(dist(counts))^2 / 2
  y <- data.frame(Population = pop)
  y[[l]] <- locus(raw[[l]][keep], type = "separated")
  Dg <- as.matrix(gstudio:::dist_amova(y))
  stopifnot(max(abs(D - Dg)) < 1e-10)
  genotypes <- two_level(dist_ss(D), sum(sapply(unique(pop), function(k) {
    i <- which(pop == k)
    dist_ss(D[i, i, drop = FALSE])
  })), as.numeric(table(pop)))
  list(locus = l, alleles = length(codes), geneCopies = geneCopies, genotypes = genotypes)
})

ratio <- function(kind) {
  a <- sum(sapply(amova_locus, function(r) r[[kind]]$sigmaAmong))
  w <- sum(sapply(amova_locus, function(r) r[[kind]]$sigmaWithin))
  a / (a + w)
}
amovaMultilocus <- list(geneCopies = ratio("geneCopies"), genotypes = ratio("genotypes"))

# The complete-data individuals: per-locus sums equal the summed-distance AMOVA.
complete_ratio <- {
  parts <- sapply(loci, function(l) {
    al <- strsplit(raw[[l]][complete], ":")
    codes <- sort(unique(unlist(al)))
    counts <- t(sapply(al, function(p) tabulate(match(p, codes), length(codes))))
    D <- as.matrix(dist(counts))^2 / 2
    pop <- raw$Population[complete]
    r <- two_level(dist_ss(D), sum(sapply(unique(pop), function(k) {
      i <- which(pop == k)
      dist_ss(D[i, i, drop = FALSE])
    })), as.numeric(table(pop)))
    c(r$sigmaAmong, r$sigmaWithin)
  })
  sum(parts[1, ]) / sum(parts)
}
stopifnot(abs(complete_ratio - amova$phiST) < 1e-10)

# ---- Nei & Chesser / Jost differentiation -------------------------------------------------------------------------

estimate_differentiation <- function(estimator) lapply(loci, function(l) {
  keep <- raw[[l]] != ""
  pop <- raw$Population[keep]
  al <- strsplit(raw[[l]][keep], ":")
  codes <- sort(unique(unlist(al)))
  counts <- t(sapply(al, function(p) tabulate(match(p, codes), length(codes))))
  p <- apply(counts / 2, 2, function(x) tapply(x, pop, mean))
  ho <- mean(tapply(sapply(al, function(g) g[1] != g[2]), pop, mean))
  sizes <- as.numeric(table(pop))
  k <- length(sizes)
  hn <- 1 / mean(1 / sizes)
  sp2 <- mean(rowSums(p^2))
  pbar2 <- sum(colMeans(p)^2)
  if (estimator == "jost") {
    hs <- 2 * hn / (2 * hn - 1) * (1 - sp2)
    ht <- 1 - pbar2 + hs / (2 * k * hn)
  } else if (estimator == "neiChesser") {
    hs <- hn / (hn - 1) * (1 - sp2 - ho / (2 * hn))
    ht <- 1 - pbar2 + hs / (k * hn) - ho / (2 * k * hn)
  } else {
    hs <- 1 - sp2
    ht <- 1 - pbar2
  }
  list(locus = l, individuals = sum(sizes), strata = k, alleles = length(codes), harmonicSize = hn,
       hs = hs, ht = ht, gst = (ht - hs) / ht,
       gstPrime = (ht - hs) * (k - 1 + hs) / (ht * (k - 1) * (1 - hs)),
       dest = (ht - hs) / (1 - hs) * k / (k - 1))
})

differentiation <- estimate_differentiation("jost")
differentiationNeiChesser <- estimate_differentiation("neiChesser")
differentiationUncorrected <- estimate_differentiation("uncorrected")

gi <- df2genind(raw[, loci], sep = ":", pop = raw$Population, NA.char = "", type = "codom")
mg <- Gst_Nei(gi)$per.locus
mj <- D_Jost(gi)$per.locus
for (j in seq_along(loci)) {
  stopifnot(abs(mg[[j]] - differentiation[[j]]$gst) < 1e-10, abs(mj[[j]] - differentiation[[j]]$dest) < 1e-10)
}

# Nei & Chesser's estimates are hierfstat's basic.stats; its Fst is Gst and its Dest is Jost's D.
bs <- basic.stats(genind2hierfstat(gi), digits = 15)$perloc
for (j in seq_along(loci)) {
  r <- differentiationNeiChesser[[j]]
  stopifnot(abs(bs[r$locus, "Hs"] - r$hs) < 1e-10, abs(bs[r$locus, "Ht"] - r$ht) < 1e-10,
            abs(bs[r$locus, "Fst"] - r$gst) < 1e-10, abs(bs[r$locus, "Dest"] - r$dest) < 1e-10)
}

multilocus <- function(rows) {
  dsum <- function(f) sum(sapply(rows, f))
  list(gst = dsum(function(r) r$ht - r$hs) / dsum(function(r) r$ht),
       gstPrime = dsum(function(r) (r$ht - r$hs) * (r$strata - 1 + r$hs)) /
         dsum(function(r) r$ht * (r$strata - 1) * (1 - r$hs)),
       dest = dsum(function(r) (r$ht - r$hs) * r$strata / (r$strata - 1)) / dsum(function(r) 1 - r$hs))
}
differentiationMultilocus <- multilocus(differentiation)

write_json(list(weirCockerham = wc, amova = amova, weirCockerhamMultilocus = wcMultilocus,
                amovaLocus = amova_locus, amovaMultilocus = amovaMultilocus,
                differentiation = differentiation, differentiationMultilocus = differentiationMultilocus,
                differentiationNeiChesser = differentiationNeiChesser,
                differentiationNeiChesserMultilocus = multilocus(differentiationNeiChesser),
                differentiationUncorrected = differentiationUncorrected,
                differentiationUncorrectedMultilocus = multilocus(differentiationUncorrected)),
           "structure_fixtures.json",
           auto_unbox = TRUE, digits = NA, pretty = TRUE)
