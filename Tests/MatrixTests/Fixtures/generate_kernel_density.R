# Prints the values `KernelDensityTests.matchesR` compares against, as Swift literals.
# Run with: Rscript Tests/MatrixTests/Fixtures/generate_kernel_density.R
#
# R's density() bins the data and uses an FFT, so it agrees with the direct
# evaluation in KernelDensity.swift only approximately.

x <- c(0.10, 0.20, 0.20, 0.30, 0.50, 0.80, 0.85, 0.40, 0.45, 0.05)
bw <- bw.nrd0(x)
d <- density(x, n = 512)
at <- seq(1, 512, length.out = 9)

cat("R", as.character(getRversion()), "\n")
cat("bandwidth:", sprintf("%.12f", bw), "\n")
cat("from:", sprintf("%.12f", d$x[1]), "to:", sprintf("%.12f", d$x[512]), "\n")
cat("x:", paste(sprintf("%.12f", d$x[at]), collapse = ", "), "\n")
cat("y:", paste(sprintf("%.12f", d$y[at]), collapse = ", "), "\n")
