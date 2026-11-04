#!/usr/bin/env Rscript
# Generates point fixtures for MapProjection (Sources/Matrix/Raster/MapProjection*.swift): longitude/latitude
# points and their projected coordinates from PROJ, through terra::project. Run with terra + jsonlite:
#
#   Rscript generate_projection_fixtures.R Tests/MatrixTests/Fixtures
#
# Each case is projected from the geographic system on its own datum, so no datum shift is involved. The points
# reach 6° either side of a UTM central meridian and the full extent each Albers system is used for, plus a
# southern-hemisphere cone (negative cone constant) and a single-standard-parallel cone.

suppressPackageStartupMessages({
  library(terra)
  library(jsonlite)
})

fixture_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(fixture_dir)) stop("pass the output Fixtures dir as arg 1")

wgs84 <- "+proj=longlat +ellps=WGS84 +no_defs"
grs80 <- "+proj=longlat +ellps=GRS80 +no_defs"

grid <- function(lons, lats) as.matrix(expand.grid(lon = lons, lat = lats))

specs <- list(
  list(id = "wgs84_utm12n", crs = "EPSG:32612", from = "EPSG:4326",
       points = grid(seq(-117, -105, by = 3), c(0, 15, 29, 45, 60))),
  list(id = "wgs84_utm12s", crs = "EPSG:32712", from = "EPSG:4326",
       points = grid(seq(-117, -105, by = 3), c(-60, -45, -23, -10, -0.5))),
  list(id = "nad83_utm12n", crs = "EPSG:26912", from = "EPSG:4269",
       points = grid(c(-116, -111, -106), c(23, 31, 49))),
  list(id = "nad83_2011_utm12n", crs = "EPSG:6341", from = "EPSG:6318",
       points = grid(c(-116, -111, -106), c(23, 31, 49))),
  list(id = "etrs89_utm32n", crs = "EPSG:25832", from = "EPSG:4258",
       points = grid(c(3, 9, 15), c(40, 52, 70))),
  list(id = "conus_albers", crs = "EPSG:5070", from = "EPSG:4269",
       points = grid(seq(-125, -66, length.out = 5), c(20, 25, 35, 45, 50))),
  list(id = "alaska_albers", crs = "EPSG:3338", from = "EPSG:4269",
       points = grid(c(-170, -154, -135), c(52, 61, 71))),
  list(id = "california_albers", crs = "EPSG:3310", from = "EPSG:4269",
       points = grid(c(-124, -120, -114), c(32.5, 37, 42))),
  list(id = "bc_albers", crs = "EPSG:3005", from = "EPSG:4269",
       points = grid(c(-139, -126, -114), c(48.3, 54, 60))),
  list(id = "custom_tmerc",
       crs = "+proj=tmerc +lat_0=25 +lon_0=-112 +k=0.9996 +x_0=500000 +y_0=10000 +ellps=WGS84 +units=m +no_defs",
       from = wgs84, points = grid(c(-116, -112, -108), c(20, 25, 31))),
  list(id = "custom_southern_albers",
       crs = "+proj=aea +lat_0=-32 +lon_0=-60 +lat_1=-20 +lat_2=-40 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs",
       from = grs80, points = grid(c(-70, -60, -50), c(-45, -32, -15))),
  list(id = "custom_one_parallel_albers",
       crs = "+proj=aea +lat_0=30 +lon_0=-100 +lat_1=35 +lat_2=35 +x_0=0 +y_0=0 +ellps=GRS80 +units=m +no_defs",
       from = grs80, points = grid(c(-110, -100, -90), c(25, 35, 45)))
)

cases <- lapply(specs, function(spec) {
  xy <- terra::project(spec$points, from = spec$from, to = spec$crs)
  list(id = spec$id, crs = spec$crs,
       points = lapply(seq_len(nrow(xy)), function(i) {
         list(longitude = spec$points[i, 1], latitude = spec$points[i, 2], x = xy[i, 1], y = xy[i, 2])
       }))
})

write_json(list(terra = as.character(packageVersion("terra")), proj = libVersion("proj"), cases = cases),
           file.path(fixture_dir, "projection_fixtures.json"), auto_unbox = TRUE, digits = NA, pretty = FALSE)
cat("wrote", length(cases), "projection cases\n")
