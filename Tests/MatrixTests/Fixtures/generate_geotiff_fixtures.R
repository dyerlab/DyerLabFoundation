#!/usr/bin/env Rscript
# Generates GeoTIFF fixtures for importGeoTIFF (Sources/Matrix/Raster/importGeoTIFF.swift).
# Run with terra + jsonlite:
#
#   Rscript generate_geotiff_fixtures.R Tests/MatrixTests/Fixtures
#
# Each case writes a small .tif with one GDAL layout (strips or tiles, compression, predictor, data type, byte
# order, BigTIFF, coordinate system) and records what terra reads back: dimensions, extent, CRS and every cell
# (NA as null). Projected cases also record PROJ's definition and three cell centres in longitude/latitude. Crop
# cases record terra::crop(x, e, snap = "out"). The "large" case only records summary sums, since it exists to
# push LZW through every code width and table reset. alt_baja.tif is the exception: a real WorldClim DEM
# (see below) that this script reads but never writes.

suppressPackageStartupMessages({
  library(terra)
  library(jsonlite)
})

fixture_dir <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(fixture_dir)) stop("pass the output Fixtures dir as arg 1")
tif_dir <- file.path(fixture_dir, "geotiff")
dir.create(tif_dir, showWarnings = FALSE, recursive = TRUE)

base_extent <- ext(-77.6, -77.2, 37.4, 37.65)

make_raster <- function(nrow, ncol, seed, integer_values = FALSE, na_fraction = 0.05, crs = "EPSG:4326") {
  set.seed(seed)
  r <- rast(nrows = nrow, ncols = ncol, extent = base_extent, crs = crs)
  v <- if (integer_values) sample(-500:3000, nrow * ncol, replace = TRUE) else runif(nrow * ncol, 50, 1500)
  v[sample.int(length(v), round(na_fraction * length(v)))] <- NA
  values(r) <- v
  r
}

describe <- function(r, full = TRUE, geographic = NULL) {
  e <- as.vector(ext(r))
  v <- as.vector(t(as.matrix(r, wide = TRUE)))
  code <- crs(r, describe = TRUE)$code
  out <- list(rows = nrow(r), cols = ncol(r),
              west = e[["xmin"]], east = e[["xmax"]], south = e[["ymin"]], north = e[["ymax"]],
              epsg = if (is.na(code)) NA_integer_ else as.integer(code),
              missing = sum(is.na(v)), sum = sum(v, na.rm = TRUE), sumOfSquares = sum(v^2, na.rm = TRUE))
  if (!is.null(geographic)) {
    # A projected raster: PROJ's definition, and the longitude/latitude of three cell centres.
    out$proj <- crs(r, proj = TRUE)
    cells <- rbind(c(0, 0), c(nrow(r) - 1, ncol(r) - 1), c(nrow(r) %/% 2, ncol(r) %/% 2))
    xy <- xyFromCell(r, cellFromRowCol(r, cells[, 1] + 1, cells[, 2] + 1))
    lonlat <- terra::project(xy, from = crs(r), to = geographic)
    out$centers <- lapply(seq_len(nrow(cells)), function(i) {
      list(row = cells[i, 1], col = cells[i, 2], longitude = lonlat[i, 1], latitude = lonlat[i, 2])
    })
  }
  if (full) out$values <- v
  out
}

cases <- list()

write_case <- function(id, r, datatype, options, full = TRUE, crop = NULL, geographic = NULL) {
  path <- file.path(tif_dir, paste0(id, ".tif"))
  writeRaster(r, path, overwrite = TRUE, datatype = datatype, gdal = options)
  back <- rast(path)
  case <- list(id = id, file = paste0("geotiff/", id, ".tif"), expected = describe(back, full, geographic))
  if (!is.null(crop)) {
    cropped <- crop(back, crop, snap = "out")
    case$crop <- list(west = crop[1], east = crop[2], south = crop[3], north = crop[4])
    case$cropped <- describe(cropped, TRUE)
  }
  cases[[length(cases) + 1]] <<- case
}

study_area <- ext(-77.47, -77.31, 37.46, 37.58)

write_case("float32_lzw_fp_predictor_tiled", make_raster(23, 37, 1), "FLT4S",
           c("COMPRESS=LZW", "PREDICTOR=3", "TILED=YES", "BLOCKXSIZE=16", "BLOCKYSIZE=16"),
           crop = study_area)
write_case("int16_deflate_predictor_strips", make_raster(23, 37, 2, integer_values = TRUE), "INT2S",
           c("COMPRESS=DEFLATE", "PREDICTOR=2", "BLOCKYSIZE=5"), crop = study_area)
write_case("uint8_packbits_strips", {
  r <- make_raster(23, 37, 3, na_fraction = 0)
  values(r) <- as.integer(values(r) > 800)
  r
}, "INT1U", c("COMPRESS=PACKBITS", "BLOCKYSIZE=4"))
write_case("float64_uncompressed_bigendian_tiled", make_raster(23, 37, 4), "FLT8S",
           c("COMPRESS=NONE", "ENDIANNESS=BIG", "TILED=YES", "BLOCKXSIZE=16", "BLOCKYSIZE=16"), crop = study_area)
write_case("int32_lzw_bigtiff", make_raster(23, 37, 5, integer_values = TRUE), "INT4S",
           c("COMPRESS=LZW", "BIGTIFF=YES"))
write_case("uint16_lzw_predictor_bigendian", {
  r <- make_raster(23, 37, 6, integer_values = TRUE)
  values(r) <- abs(values(r))
  r
}, "INT2U", c("COMPRESS=LZW", "PREDICTOR=2", "ENDIANNESS=BIG", "BLOCKYSIZE=3"))
write_case("float32_nad83_deflate", make_raster(23, 37, 7, crs = "EPSG:4269"), "FLT4S",
           c("COMPRESS=DEFLATE", "PREDICTOR=3"))
write_case("float32_lzw_large", make_raster(150, 200, 8), "FLT4S", c("COMPRESS=LZW"), full = FALSE)
write_case("int16_lzw_large_tiled", make_raster(150, 200, 9, integer_values = TRUE), "INT2S",
           c("COMPRESS=LZW", "PREDICTOR=2", "TILED=YES", "BLOCKXSIZE=128", "BLOCKYSIZE=128"), full = FALSE)

# Projected rasters: UTM and Albers by EPSG code, and custom Transverse Mercator and Albers parameters, which
# GDAL writes as user-defined GeoKeys. Each crop box is roughly the inner half of the raster in its own metres,
# with edges kept off cell boundaries: where an edge lands on one (to within rounding) terra snaps the lower and
# upper edges with different tolerances, and RasterWindow deliberately treats both alike.
inner_half <- function(r) {
  e <- as.vector(ext(r))
  w <- e[["xmax"]] - e[["xmin"]]
  h <- e[["ymax"]] - e[["ymin"]]
  ext(e[["xmin"]] + 0.237 * w, e[["xmax"]] - 0.263 * w, e[["ymin"]] + 0.229 * h, e[["ymax"]] - 0.271 * h)
}
wgs84 <- "+proj=longlat +ellps=WGS84 +no_defs"
grs80 <- "+proj=longlat +ellps=GRS80 +no_defs"
projected_case <- function(id, crs, seed, geographic, datatype = "FLT4S", options = c("COMPRESS=LZW"),
                           integer_values = FALSE) {
  r <- project(make_raster(23, 37, seed, integer_values = integer_values), crs,
               method = if (integer_values) "near" else "bilinear")
  write_case(id, r, datatype, options, crop = inner_half(r), geographic = geographic)
}
projected_case("float32_wgs84_utm18n_lzw", "EPSG:32618", 13, wgs84)
projected_case("int16_nad83_utm18n_deflate", "EPSG:26918", 14, grs80, "INT2S",
               c("COMPRESS=DEFLATE", "PREDICTOR=2"), integer_values = TRUE)
projected_case("float32_conus_albers_tiled", "EPSG:5070", 15, grs80, "FLT4S",
               c("COMPRESS=LZW", "PREDICTOR=3", "TILED=YES", "BLOCKXSIZE=16", "BLOCKYSIZE=16"))
projected_case("float32_custom_albers",
               "+proj=aea +lat_0=36 +lon_0=-78 +lat_1=37 +lat_2=39 +x_0=200000 +y_0=-10000 +ellps=GRS80 +units=m +no_defs",
               16, grs80, "FLT4S", c("COMPRESS=DEFLATE"))
projected_case("float32_custom_tmerc",
               "+proj=tmerc +lat_0=37 +lon_0=-77.5 +k=0.9999 +x_0=300000 +y_0=50000 +ellps=WGS84 +units=m +no_defs",
               17, wgs84)

# Files the importer must reject.
unlink(file.path(tif_dir, "projected_albers.tif"))
writeRaster(project(make_raster(23, 37, 10), "EPSG:6372"), file.path(tif_dir, "projected_lcc.tif"),
            overwrite = TRUE)
two_band <- c(make_raster(23, 37, 11), make_raster(23, 37, 12))
writeRaster(two_band, file.path(tif_dir, "two_bands.tif"), overwrite = TRUE)

# A real file: WorldClim 30-arc-second elevation over Baja California (alt_baja.tif, copied in unchanged rather
# than rewritten by terra). It is checked whole by summary sums, cropped to the arapat study area (the sampling
# sites' bounds plus 10% per side, as GeographicBounds.buffered does), and point by point at each arapat population.
arapat <- read.csv(file.path(fixture_dir, "../../../Sources/PopulationGenetics/ExampleData/arapat.csv"))
sites <- unique(arapat[, c("Population", "Longitude", "Latitude")])
lon_pad <- max(0.1 * diff(range(sites$Longitude)), 0.01)
lat_pad <- max(0.1 * diff(range(sites$Latitude)), 0.01)
arapat_area <- c(min(sites$Longitude) - lon_pad, max(sites$Longitude) + lon_pad,
                 min(sites$Latitude) - lat_pad, max(sites$Latitude) + lat_pad)
dem <- rast(file.path(tif_dir, "alt_baja.tif"))
site_values <- extract(dem, as.matrix(sites[, c("Longitude", "Latitude")]))[, 1]
cases[[length(cases) + 1]] <- list(
  id = "alt_baja", file = "geotiff/alt_baja.tif", expected = describe(dem, FALSE),
  crop = list(west = arapat_area[1], east = arapat_area[2], south = arapat_area[3], north = arapat_area[4]),
  cropped = describe(crop(dem, ext(arapat_area), snap = "out"), FALSE),
  points = lapply(seq_len(nrow(sites)), function(i) {
    list(population = as.character(sites$Population[i]), longitude = sites$Longitude[i],
         latitude = sites$Latitude[i], value = site_values[i])
  }))

write_json(list(terra = as.character(packageVersion("terra")), gdal = gdal(), cases = cases),
           file.path(fixture_dir, "geotiff_fixtures.json"), auto_unbox = TRUE, digits = NA, na = "null", pretty = FALSE)
cat("wrote", length(cases), "cases\n")
