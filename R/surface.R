# Kõkõva 900 (2026) — road surface along the route, from OpenStreetMap.
#
# The pacing model's largest free parameter is speed, and speed on this route is
# mostly a function of what is under the tyres. The organiser quotes 60%
# forest/gravel overall, but that average is useless for planning: the opening
# leg to Rohuküla is largely asphalt and the island sections are not, and it is
# the opening leg that decides which ferry you make.
#
# This resolves the surface per kilometre so `push_kmh` and `moving_kmh` can be
# set from data rather than from a guess.
#
# Method: pull every highway way in a narrow corridor with its geometry, then
# snap each track point to the nearest way segment and inherit its tags. A plain
# `around` query per point would be far too slow, and a bounding box would drag
# in half of Estonia.
#
# Run: make surface   (or  Rscript R/surface.R)

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(purrr)
  library(readr)
  library(httr2)
})

source("R/plan.R")

OUT_CSV <- file.path(DIR_DATA, "surface.csv")

SAMPLE_M  <- 200     # resolution of the surface profile
CORRIDOR_M <- 25     # how far a way may sit from the track and still be "the road"
CHUNK_PTS <- 60      # probe points per Overpass query (geometry makes these heavy)
OVERPASS  <- "https://overpass-api.de/api/interpreter"
UA        <- "kokova-2026-surface/1.0 (+https://github.com/tpall/kokova-2026)"

if (!file.exists(KMZ_FILE)) stop("Need ", KMZ_FILE, " to resolve surfaces along the route.")

trk <- read_track()
cat(sprintf("Track: %.1f km\n", max(trk$km)))

targets <- seq(0, max(trk$km), by = SAMPLE_M / 1000)
idx     <- vapply(targets, function(t) which.min(abs(trk$km - t)), integer(1))
probes  <- trk[unique(idx), c("lat", "lon", "km")]
cat(sprintf("Probe points: %d (every %d m)\n", nrow(probes), SAMPLE_M))

query_chunk <- function(rows) {
  coords <- paste(sprintf("%.5f,%.5f", rows$lat, rows$lon), collapse = ",")
  q <- sprintf("[out:json][timeout:180];way(around:%d,%s)[highway];out geom tags;",
               CORRIDOR_M, coords)
  resp <- request(OVERPASS) |>
    req_user_agent(UA) |>
    req_body_form(data = q) |>
    req_retry(max_tries = 5, backoff = ~ min(60, 10 * 2^.x),
              is_transient = \(r) resp_status(r) %in% c(429, 502, 503, 504)) |>
    req_throttle(capacity = 1, fill_time_s = 8) |>
    req_perform()
  resp_body_json(resp)$elements
}

chunks <- split(probes, ceiling(seq_len(nrow(probes)) / CHUNK_PTS))
cat("Querying Overpass in", length(chunks), "chunks ...\n")

ways <- list()
for (i in seq_along(chunks)) {
  el <- query_chunk(chunks[[i]])
  ways <- c(ways, el)
  cat(sprintf("  chunk %d/%d: %d ways\n", i, length(chunks), length(el)))
}

# Flatten way geometries into a point table, carrying the tags we care about.
seg <- map_dfr(ways, function(w) {
  g <- w$geometry
  if (is.null(g) || length(g) < 1) return(tibble())
  tg <- w$tags
  tibble(
    lat       = vapply(g, \(p) p$lat, numeric(1)),
    lon       = vapply(g, \(p) p$lon, numeric(1)),
    highway   = tg$highway   %||% NA_character_,
    surface   = tg$surface   %||% NA_character_,
    tracktype = tg$tracktype %||% NA_character_,
    smoothness = tg$smoothness %||% NA_character_
  )
}) |> distinct()

cat("Way vertices:", nrow(seg), "\n")

# Snap each probe to the nearest way vertex. Vertices are dense enough at this
# resolution that nearest-vertex and nearest-segment agree in practice.
nearest <- function(lat, lon) {
  d <- haversine(seg$lat, seg$lon, lat, lon)
  j <- which.min(d)
  c(j = j, d = d[j])
}
hit <- t(vapply(seq_len(nrow(probes)), \(i) nearest(probes$lat[i], probes$lon[i]), numeric(2)))

# OSM surface values are a long tail; collapse to what actually changes speed.
PAVED   <- c("asphalt", "paved", "concrete", "concrete:plates", "paving_stones", "chipseal")
GRAVEL  <- c("gravel", "fine_gravel", "compacted", "pebblestone", "unpaved", "limestone")
LOOSE   <- c("ground", "dirt", "earth", "grass", "sand", "mud", "woodchips")

classify <- function(surface, highway, tracktype) {
  case_when(
    surface %in% PAVED  ~ "asfalt",
    surface %in% GRAVEL ~ "kruus",
    surface %in% LOOSE  ~ "pinnas",
    # Untagged surface: infer from the highway class. Estonian primary and
    # secondary roads are asphalt in practice; a `track` is not.
    is.na(surface) & highway %in% c("motorway", "trunk", "primary", "secondary",
                                    "tertiary", "residential", "living_street") ~ "asfalt (eeldus)",
    is.na(surface) & highway == "track" & !is.na(tracktype) & tracktype == "grade1" ~ "kruus",
    is.na(surface) & highway %in% c("track", "path", "bridleway") ~ "kruus (eeldus)",
    TRUE ~ "teadmata"
  )
}

surface <- probes |>
  mutate(
    dist_m    = round(hit[, 2]),
    highway   = seg$highway[hit[, 1]],
    surface   = seg$surface[hit[, 1]],
    tracktype = seg$tracktype[hit[, 1]],
    smoothness = seg$smoothness[hit[, 1]]
  ) |>
  mutate(klass = if_else(dist_m > CORRIDOR_M * 2, "teadmata",
                         classify(surface, highway, tracktype))) |>
  select(km, klass, surface, highway, tracktype, smoothness, dist_m)

write_csv(surface, OUT_CSV)
cat("Wrote", OUT_CSV, "-", nrow(surface), "points\n\n")

share <- surface |> count(klass, sort = TRUE) |> mutate(pct = round(100 * n / sum(n)))
print(share, n = Inf)

cat("\nAvaetapp (km 0 – 181.6):\n")
surface |> filter(km <= 181.6) |> count(klass, sort = TRUE) |>
  mutate(pct = round(100 * n / sum(n))) |> print(n = Inf)
