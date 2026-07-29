# Kõkõva 900 (2026) — resupply points along the route, from OpenStreetMap.
#
# A route-derived build step, like prepare_route.R: it reads the track, asks
# Overpass what sits within a corridor around it, and writes data/resupply.csv.
# Re-run only when the route changes — the daily job does not touch it.
#
# Why this matters more here than on a continental route: the loop spends
# ~500 km on Hiiumaa, Saaremaa and Muhu, where shops are village-sized and shut
# by early evening. The race starts at 21:00 on a Friday, so the first night and
# every night after it is ridden with nothing open.
#
# Run: make resupply   (or  Rscript R/resupply.R)

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(purrr)
  library(readr)
  library(httr2)
})

source("R/plan.R")

OUT_CSV <- file.path(DIR_DATA, "resupply.csv")

SAMPLE_M    <- 1000   # spacing of the probe points along the track
RADIUS_M    <- 1500   # corridor half-width; must exceed SAMPLE_M/2 for full coverage
CHUNK_PTS   <- 100    # probe points per Overpass query
OVERPASS    <- "https://overpass-api.de/api/interpreter"
UA          <- "kokova-2026-resupply/1.0 (+https://github.com/tpall/kokova-2026)"

# Categories worth a stop, ordered roughly by how much food they can provide.
SHOPS    <- c("supermarket", "convenience", "general", "kiosk", "bakery", "greengrocer", "butcher")
AMENITY  <- c("fuel", "cafe", "restaurant", "fast_food", "drinking_water")

if (!file.exists(TRACK_FILE)) stop("Need ", TRACK_FILE, " to locate resupply points along the route.")

trk <- read_track()
cat(sprintf("Track: %.1f km\n", max(trk$km)))

# ── Probe points ──────────────────────────────────────────────────────────────

targets <- seq(0, max(trk$km), by = SAMPLE_M / 1000)
idx     <- vapply(targets, function(t) which.min(abs(trk$km - t)), integer(1))
probes  <- trk[unique(idx), c("lat", "lon")]
cat(sprintf("Probe points: %d (every %d m, radius %d m)\n", nrow(probes), SAMPLE_M, RADIUS_M))

# ── Query Overpass in chunks ──────────────────────────────────────────────────
# `around` accepts a coordinate list, which makes the corridor a true polyline
# buffer rather than a bounding box — important on a route this convoluted.

query_chunk <- function(rows) {
  coords <- paste(sprintf("%.5f,%.5f", rows$lat, rows$lon), collapse = ",")
  q <- sprintf(
    "[out:json][timeout:180];\n(\n  nwr(around:%d,%s)[shop~\"^(%s)$\"];\n  nwr(around:%d,%s)[amenity~\"^(%s)$\"];\n);\nout center tags;",
    RADIUS_M, coords, paste(SHOPS, collapse = "|"),
    RADIUS_M, coords, paste(AMENITY, collapse = "|"))

  resp <- request(OVERPASS) |>
    req_user_agent(UA) |>
    req_body_form(data = q) |>
    # Overpass answers 429 when queried too fast and 504 when the server is
    # loaded; both are worth waiting out rather than dropping a chunk.
    req_retry(max_tries = 5, backoff = ~ min(60, 10 * 2^.x),
              is_transient = \(r) resp_status(r) %in% c(429, 502, 503, 504)) |>
    req_throttle(capacity = 1, fill_time_s = 8) |>
    req_perform()

  resp_body_json(resp)$elements
}

chunks <- split(probes, ceiling(seq_len(nrow(probes)) / CHUNK_PTS))
cat("Querying Overpass in", length(chunks), "chunks ...\n")

elements <- list()
for (i in seq_along(chunks)) {
  el <- query_chunk(chunks[[i]])
  elements <- c(elements, el)
  cat(sprintf("  chunk %d/%d: %d elements\n", i, length(chunks), length(el)))
}

# ── Flatten, dedupe, locate along the route ───────────────────────────────────

pois <- map_dfr(elements, function(e) {
  tg  <- e$tags
  lat <- e$lat %||% e$center$lat
  lon <- e$lon %||% e$center$lon
  if (is.null(lat) || is.null(lon)) return(tibble())
  # A POI often carries both tags — a filling station tagged shop=car_parts plus
  # amenity=fuel, or a café sitting on a building tagged shop=no. Take whichever
  # tag actually matched the query, preferring the shop only when it is one we
  # asked for, otherwise the label ends up as "no" or "mustard".
  shop <- tg$shop %||% NA_character_
  amen <- tg$amenity %||% NA_character_
  kind <- if (!is.na(shop) && shop %in% SHOPS) shop
          else if (!is.na(amen) && amen %in% AMENITY) amen
          else NA_character_
  if (is.na(kind)) return(tibble())
  tibble(
    osm   = paste0(e$type, "/", e$id),
    kind  = kind,
    name  = tg$name %||% NA_character_,
    hours = tg$opening_hours %||% NA_character_,
    lat = lat, lon = lon
  )
}) |>
  distinct(osm, .keep_all = TRUE)

cat("Unique POIs:", nrow(pois), "\n")

# Snap each POI to the nearest track point: km along the route, and how far off
# it sits. Riding out and back doubles the detour, which is what `detour_m`
# means downstream.
snap <- function(lat, lon) {
  d <- haversine(trk$lat, trk$lon, lat, lon)
  j <- which.min(d)
  c(km = trk$km[j], off = d[j])
}
snapped <- t(vapply(seq_len(nrow(pois)), \(i) snap(pois$lat[i], pois$lon[i]), numeric(2)))

resupply <- pois |>
  mutate(km = round(snapped[, 1], 2), detour_m = round(snapped[, 2])) |>
  filter(detour_m <= RADIUS_M) |>
  arrange(km, detour_m) |>
  select(km, detour_m, kind, name, hours, lat, lon, osm)

write_csv(resupply, OUT_CSV)
cat("Wrote", OUT_CSV, "-", nrow(resupply), "points\n")
cat("By kind:\n"); print(count(resupply, kind, sort = TRUE), n = Inf)
