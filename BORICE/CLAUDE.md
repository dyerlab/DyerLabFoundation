# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

BORICE is a Bayesian analysis tool for estimating population mean outcrossing rates and inbreeding coefficients from genetic marker data. The software uses Markov Chain Monte Carlo (MCMC) methods to infer mating system parameters from family-level genotype data.

## Running BORICE

**Basic command:**
```bash
python BORICE.py <csv_file> <locus_model_flags> <num_steps> <burn_in> <t_tuning> <af_tuning> <initial_t> [output_flags]
```

**Example:**
```bash
python BORICE.py test_data.csv 0 0 0 10000 999 0.05 0.1 0.5
```

**Parameters:**
- CSV file containing genotype data
- Locus model flags: one boolean per locus (0 or 1) indicating whether null alleles are modeled at that locus
- `num_steps`: Total MCMC iterations (e.g., 100000)
- `burn_in`: Number of initial steps to discard (e.g., 999)
- `t_tuning`: Outcrossing rate tuning parameter (default: 0.05)
- `af_tuning`: Allele frequency tuning parameter (default: 0.1)
- `initial_t`: Initial outcrossing rate value (default: 0.5)
- Optional output flags: Three booleans (0 or 1) to control which output files are generated

**Outputs:**
- `BORICE_output1.txt`: Posterior distributions of inbreeding history, t, F, and allele frequencies
- `BORICE_output2.txt`: Maternal inbreeding histories per family (optional)
- `BORICE_output3.txt`: t, F, and ln likelihood values every 10 steps post-burn-in (optional)
- `BORICE_output4.txt`: Maternal genotype posterior distributions (optional)

## Input Data Format

The CSV file must follow this structure:

**Row 1:** `<num_loci>,<pop_name_present>,<subgroup_present>`
- First cell: Number of marker loci
- Second cell: 1 if population names are present, 0 otherwise
- Third cell: Must be 0 (subgroups not supported)

**Row 2:** Marker locus names (one per locus)

**Subsequent rows:** Genotype data in format:
`<family_id>[!],<population_name>,<locus1_allele1>,<locus1_allele2>,<locus2_allele1>,<locus2_allele2>,...`

- Family ID ending with `!` indicates maternal individual
- Missing data coded as `-9`
- Each locus requires two consecutive columns for diploid alleles

## Architecture

**Core Object Model:**

The code uses an object-oriented design with hierarchical relationships:

- **Population** → contains multiple **Family** objects and population-level parameters (outcrossing rate, allele frequencies)
- **Family** → contains one maternal **Individual** and multiple offspring **Individual** objects, plus family-level inbreeding history
- **Individual** → contains a list of **SingleLocusGenotype** objects (multilocus genotype) and an inbreeding coefficient
- **SingleLocusGenotype** → contains two alleles and imputation status flags
- **Allele** → represents an allele with frequency tracking

**MCMC Inference Process:**

The `BORICE.main()` method implements a Metropolis-Hastings MCMC algorithm that iterates through these steps:

1. **Outcrossing rate (t) update**: Proposes new outcrossing rate, calculates population likelihood, accepts/rejects based on Metropolis ratio
2. **Inbreeding history (IH) update**: For each family, samples new IH value from discrete distribution, updates maternal inbreeding coefficient (F)
3. **Allele frequency updates** (every 10 steps): Uses Dirichlet-like sampling via y-values; updates one random allele per locus
4. **Maternal genotype imputation**: For each family with imputed maternal loci, proposes new genotype consistent with offspring, accepts/rejects based on family likelihood

**Key Functions:**

- `parse_csv()`: Parses input CSV into Family and Individual objects
- `Family.infer_mom()`: Imputes missing maternal genotypes from offspring data using `find_mom_genotype()` or validates observed genotypes with `tag_mom_genotype()`
- `Individual.calc_prob_offspring_geno()`: Calculates offspring genotype probability as weighted sum of selfing and outcrossing probabilities
- `Individual.calc_prob_mom_geno()`: Calculates maternal genotype probability under Hardy-Weinberg equilibrium with inbreeding
- `Population.calc_pop_lnL()`: Sums log-likelihoods across all families

**Null Allele Handling:**

When a locus has null alleles enabled in the model:
- Allele 0 represents the unobserved null allele
- Observed homozygotes may actually be null heterozygotes
- `observed_imputed` flag tracks ambiguous maternal homozygotes that could be null hets
- Probability calculations use modified methods (e.g., `calc_prob_offspring_given_selfing_mom_homozygote_null_model()`)

**Testing:**

The code can use a fixed random seed for reproducibility:
```bash
export BORICE_RAND_SEED=12345
python BORICE.py test_data.csv ...
```

## Important Implementation Notes

- The code uses Python 2 syntax (`long()`, `next()` method, `print` statements)
- Inbreeding coefficient F is calculated from inbreeding history IH via: `F = 1 - 0.5^IH` (capped at F=1.0 for IH≥6)
- Allele frequencies are stored as lists indexed to match `allele_list` for each locus
- Genotype imputation only occurs at loci flagged as `imputed=True` or `observed_imputed=True`
- The MCMC chain stores parameter values every 10 steps after burn-in for posterior distributions
