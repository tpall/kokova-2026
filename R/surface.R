# Kõkõva 900 (2026) — road surface along the route, from OpenStreetMap.
#
# The pacing model's largest free parameter is speed, and speed here is mostly a
# function of what is under the tyres. The organiser quotes 60% forest/gravel
# overall, but that average is useless for planning: the opening leg to Rohuküla
# is largely asphalt and the island sections are not, and it is the opening leg
# that decides which ferry you make.
#
# Data comes from a local Geofabrik extract rather than Overpass. Resolving
# surface for ~2000 points along a 985 km route means asking for way geometry,
# which the public Overpass endpoints answer with 504 well before the job
# finishes — and a whole-country extract is only ~120 MB, reads through GDAL's
# OSM driver, and makes re-runs instant.
#
# Run: make surface   (or  Rscript R/surface.R)

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(readr)
  library(sf)
})

source("R/plan.R")

OUT_CSV   <- file.path(DIR_DATA, "surface.csv")
CACHE_DIR <- "cache"                       # gitignored; the extract is large
PBF       <- file.path(CACHE_DIR, "estonia-latest.osm.pbf")
PBF_URL   <- "https://download.geofabrik.de/europe/estonia-latest.osm.pbf"

SAMPLE_M   <- 250    # resolution of the surface profile
CORRIDOR_M <- 30     # beyond this the nearest way is not the road we are on

if (!file.exists(KMZ_FILE)) stop("Need ", KMZ_FILE, " to resolve surfaces along the route.")

if (!file.exists(PBF)) {
  dir.create(CACHE_DIR, showWarnings = FALSE)
  cat("Downloading Estonia OSM extract (~120 MB, once) ...\n")
  download.file(PBF_URL, PBF, mode = "wb", quiet = FALSE)
}
cat(sprintf("Extract: %s (%.0f MB)\n", PBF, file.size(PBF) / 1e6))

trk <- read_track()
targets <- seq(0, max(trk$km), by = SAMPLE_M / 1000)
idx     <- vapply(targets, function(t) which.min(abs(trk$km - t)), integer(1))
probes  <- trk[unique(idx), c("lat", "lon", "km")]
cat(sprintf("Track %.1f km, %d probe points every %d m\n",
            max(trk$km), nrow(probes), SAMPLE_M))

# Read via a SQL query rather than layer + wkt_filter. Reading the `lines` layer
# directly makes GDAL's OSM driver accumulate the whole points layer as well and
# it then silently drops most features — "Too many features have accumulated in
# points layer". The symptom is a nearest road 1.4 km away on a route that
# follows roads. A query touches only `lines` and returns the whole country in
# about ten seconds. Do NOT set OGR_INTERLEAVED_READING here: with sf it resets
# the feature count to zero and returns nothing.
Sys.setenv(OSM_MAX_TMPFILE_SIZE = "4000")

cat("Reading highways from the extract ...\n")
roads <- st_read(PBF, quiet = TRUE,
                 query = "SELECT highway, other_tags FROM lines WHERE highway IS NOT NULL")
cat("Highway ways in Estonia:", nrow(roads), "\n")

# Trim to the route's bounding box before the nearest-feature search.
pad <- 0.03
roads <- roads[st_intersects(roads,
  st_as_sfc(st_bbox(c(xmin = min(trk$lon) - pad, ymin = min(trk$lat) - pad,
                      xmax = max(trk$lon) + pad, ymax = max(trk$lat) + pad),
                    crs = 4326)), sparse = FALSE)[, 1], ]
cat("Highway ways in corridor:", nrow(roads), "\n")

# GDAL's OSM driver folds everything except a few promoted keys into an HSTORE
# string, so surface and friends have to be pulled back out of `other_tags`.
tag <- function(x, key) {
  m <- regmatches(x, regexpr(sprintf('"%s"=>"[^"]*"', key), x))
  out <- rep(NA_character_, length(x))
  hit <- lengths(m) > 0 | nzchar(m)
  out[hit] <- sub(sprintf('^"%s"=>"(.*)"$', key), "\\1", m[hit])
  out
}
roads$surface    <- tag(roads$other_tags, "surface")
roads$tracktype  <- tag(roads$other_tags, "tracktype")
roads$smoothness <- tag(roads$other_tags, "smoothness")

pts <- st_as_sf(probes, coords = c("lon", "lat"), crs = 4326)
cat("Snapping probes to nearest way ...\n")
near <- st_nearest_feature(pts, roads)
dist <- as.numeric(st_distance(pts, roads[near, ], by_element = TRUE))

# OSM surface values are a long tail; collapse to what actually changes speed.
PAVED  <- c("asphalt", "paved", "concrete", "concrete:plates", "paving_stones", "chipseal")
GRAVEL <- c("gravel", "fine_gravel", "compacted", "pebblestone", "unpaved", "limestone")
LOOSE  <- c("ground", "dirt", "earth", "grass", "sand", "mud", "woodchips")

classify <- function(surface, highway, tracktype) {
  case_when(
    surface %in% PAVED  ~ "asfalt",
    surface %in% GRAVEL ~ "kruus",
    surface %in% LOOSE  ~ "pinnas",
    # Untagged surface: infer from road class. Estonian trunk through tertiary
    # roads are asphalt in practice; a `track` is not.
    is.na(surface) & highway %in% c("motorway", "trunk", "primary", "secondary",
                                    "tertiary", "residential", "living_street",
                                    "unclassified") ~ "asfalt (eeldus)",
    is.na(surface) & highway == "track" & tracktype %in% "grade1" ~ "kruus",
    is.na(surface) & highway %in% c("track", "path", "bridleway", "cycleway",
                                    "footway") ~ "kruus (eeldus)",
    TRUE ~ "teadmata"
  )
}

surface <- probes |>
  mutate(dist_m     = round(dist),
         highway    = roads$highway[near],
         surface    = roads$surface[near],
         tracktype  = roads$tracktype[near],
         smoothness = roads$smoothness[near]) |>
  mutate(klass = if_else(dist_m > CORRIDOR_M, "teadmata",
                         classify(surface, highway, tracktype))) |>
  select(km, klass, surface, highway, tracktype, smoothness, dist_m)

write_csv(surface, OUT_CSV)
cat("Wrote", OUT_CSV, "-", nrow(surface), "points\n\n")

show <- function(d, label) {
  cat(label, "\n")
  d |> count(klass, sort = TRUE) |> mutate(pct = round(100 * n / sum(n))) |> print(n = Inf)
  cat("\n")
}
show(surface, "KOGU RADA:")
show(surface |> filter(km <= FERRIES$km_from[FERRIES$leg == "ROH-HEL"]), "AVAETAPP (0 → Rohuküla):")
show(surface |> filter(km > FERRIES$km_to[FERRIES$leg == "ROH-HEL"],
                       km <= FERRIES$km_from[FERRIES$leg == "SOR-TRI"]), "HIIUMAA:")
show(surface |> filter(km > FERRIES$km_to[FERRIES$leg == "SOR-TRI"],
                       km <= FERRIES$km_from[FERRIES$leg == "KUI-VIR"]), "SAAREMAA + MUHU:")
show(surface |> filter(km > FERRIES$km_to[FERRIES$leg == "KUI-VIR"]), "TAGASITEE MANDRIL:")
