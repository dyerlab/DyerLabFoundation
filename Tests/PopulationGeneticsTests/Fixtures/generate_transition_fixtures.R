# Generates transition_fixtures.json for TransitionProbabilityTests.
#
# gstudio's transition_probability() (1.15.3) for every offspring of the bundled cornus families (468 and 474) with
# its own mother: per locus and multilocus, (1) the one-parent compatibility score, (2) one parent and a random mate,
# with the allele frequencies of all 62 individuals pooled (frequencies()), and (3) two parents, with the other
# family's mother as the candidate father. A genotype missing at a locus is NA there and left out of the product.
#
# Run from this directory:  Rscript generate_transition_fixtures.R
# Needs gstudio (>= 1.15.3) and jsonlite.

suppressPackageStartupMessages({
  library(gstudio)
  library(jsonlite)
})

raw <- read.csv("../../../Sources/PopulationGenetics/ExampleData/cornus.csv", colClasses = "character",
                check.names = FALSE)
loci <- c("G8", "H18", "N5", "N10", "O5")
df <- data.frame(ID = raw$ID, OffID = raw$OffID, stringsAsFactors = FALSE)
for (l in loci) df[[l]] <- locus(raw[[l]], type = "separated")
freqs <- frequencies(df)

mother <- function(family) df[df$ID == family & df$OffID == "0", ]
other <- c("468" = "474", "474" = "468")
na_null <- function(v) lapply(v, function(x) if (is.na(x)) NULL else unname(x))

rows <- lapply(which(df$OffID != "0"), function(i) {
  off <- df[i, ]
  mom <- mother(off$ID)
  dad <- mother(other[[off$ID]])
  list(family = off$ID, offspring = off$OffID, father = dad$ID,
       compatibility = na_null(transition_probability(off, mom, multilocus = FALSE)),
       randomMate = na_null(transition_probability(off, mom, freqs = freqs, multilocus = FALSE)),
       twoParent = na_null(transition_probability(off, mom, dad, multilocus = FALSE)),
       compatibilityMultilocus = transition_probability(off, mom),
       randomMateMultilocus = transition_probability(off, mom, freqs = freqs),
       twoParentMultilocus = transition_probability(off, mom, dad))
})

write_json(list(loci = loci, offspring = rows), "transition_fixtures.json", auto_unbox = TRUE, digits = NA,
           pretty = TRUE, null = "null")
