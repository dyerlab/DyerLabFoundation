# Generates maternal_inference_genotypes.csv and maternal_inference_fixtures.json for MaternalInferenceTests.
#
# gstudio's PhiFT (1.15.5) reconstructs a mother missing at a locus from her offspring before removing her
# contribution (gstudio:::.infer_maternal): every pair of alleles seen at the locus is a candidate, scored by
# prod_o 1/2 [P(o | a transmitted) + P(o | b transmitted)] with the paternal allele drawn from the allele frequencies
# of the mothers and offspring pooled, and the best is used when it is at least 20 times as likely as the next best.
#
# The bundled cornus data have offspring in two families, 468 and 474. Both mothers are blanked at every locus, which
# gives ten reconstructions covering every case: used with a finite ratio, used as the only compatible genotype, and
# not used (ratios of about 7). The other mothers stay genotyped, so they count towards the allele frequencies.
#
# Run from this directory:  Rscript generate_maternal_inference_fixtures.R
# Needs gstudio (>= 1.15.5) and jsonlite.

suppressPackageStartupMessages({
  library(gstudio)
  library(jsonlite)
})

raw <- read.csv("../../../Sources/PopulationGenetics/ExampleData/cornus.csv", colClasses = "character",
                check.names = FALSE)
loci <- c("G8", "H18", "N5", "N10", "O5")
blank <- raw$OffID == "0" & raw$ID %in% c("468", "474")
raw[blank, loci] <- ""
write.csv(raw, "maternal_inference_genotypes.csv", row.names = FALSE, quote = FALSE)

df <- data.frame(ID = raw$ID, OffID = raw$OffID, stringsAsFactors = FALSE)
for (l in loci) df[[l]] <- locus(raw[[l]], type = "separated")
report <- suppressMessages(gstudio:::.infer_maternal(df, stratum = "ID", offspring = "OffID", loci = loci))$report

rows <- lapply(seq_len(nrow(report)), function(i) {
  r <- report[i, ]
  list(family = r$Family, locus = r$Locus, offspring = r$Offspring, genotype = r$Genotype, alternative = r$Next,
       likelihoodRatio = if (is.infinite(r$LR)) "Inf" else r$LR, used = r$Used)
})
write_json(list(inferences = rows), "maternal_inference_fixtures.json", auto_unbox = TRUE, digits = NA,
           pretty = TRUE)
