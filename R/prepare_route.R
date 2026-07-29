# Kõkõva 900 (2026) — derive the committed route files from the final GPX parts.
#
# Run this once whenever a new track arrives, then commit what it writes.
# Keeping the geometry as committed derivatives means the daily CI job does not
# re-parse 20 500 track points on every run, and the numbers that feed the
# wind-exposure calculation can be diffed rather than silently recomputed.
#
#   data/kokova_2026_900_final.gpx  the three organiser parts concatenated into
#                                   one track — what read_track() and the
#                                   vendored gpsweather engine read
#   waypoints.csv        24 waypoints: km, name, coordinates, elevation, type,
#                        and the direction of travel at that point
#   route_directions.csv distance-weighted histogram of travel direction over
#                        the whole route, 1° bins — what the wind-exposure
#                        calculation in weather_outlook.R needs
#
# Waypoint names and kms are hand-curated (reverse geocoding returns bare
# municipality names for much of Saaremaa), so this script preserves the
# existing rows, only recomputes route_deg, and warns if a row's km disagrees
# with where its coordinates actually sit on the track.
#
# Run: make route   (or  Rscript R/prepare_route.R)

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(xml2)
})

source("R/plan.R")

missing <- GPX_PARTS[!file.exists(GPX_PARTS)]
if (length(missing)) {
  stop("Need the final route parts to regenerate the route files: ",
       paste(missing, collapse = ", "))
}

# ── Concatenate the three parts into the committed track ──────────────────────
# The parts join seamlessly at CP1 (Paluküla); the Kuivastu–Virtsu ferry is the
# gap between parts 2 and 3 and stays a gap — one 6.7 km step in the merged
# track, which read_track()'s cumulative km then carries across, exactly as the
# FERRIES table expects.

read_part <- function(gpx) {
  x  <- read_xml(gpx)
  ns <- xml_ns(x)
  pt <- xml_find_all(x, "//d1:trkpt", ns)
  tibble(
    lon = as.numeric(xml_attr(pt, "lon")),
    lat = as.numeric(xml_attr(pt, "lat")),
    ele = xml_double(xml_find_first(pt, "./d1:ele", ns))
  )
}

trk <- bind_rows(lapply(GPX_PARTS, read_part)) |>
  mutate(step = c(0, haversine(head(lat, -1), head(lon, -1),
                               tail(lat, -1), tail(lon, -1))),
         km   = cumsum(step) / 1000)

writeLines(c(
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="prepare_route.R">',
  '<trk><name>KÕKÕVA 900 2026 (final, parts 1-3 merged)</name><trkseg>',
  sprintf('<trkpt lat="%.6f" lon="%.6f"><ele>%.1f</ele></trkpt>',
          trk$lat, trk$lon, trk$ele),
  '</trkseg></trk></gpx>'), TRACK_FILE)

in_ferry <- Reduce(`|`, lapply(seq_len(nrow(FERRIES)), function(i)
  trk$km > FERRIES$km_from[i] & trk$km <= FERRIES$km_to[i]))

cat(sprintf("Track: %.1f km over %d points (%.1f km ridden, %.1f km on ferries)\n",
            max(trk$km), nrow(trk),
            sum(trk$step[!in_ferry]) / 1000, sum(trk$step[in_ferry]) / 1000))
cat("Wrote", TRACK_FILE, "\n")
if (abs(max(trk$km) - TOTAL_ROUTE_KM) > 0.5) {
  warning(sprintf("Track total %.1f km disagrees with TOTAL_ROUTE_KM = %.1f in R/plan.R",
                  max(trk$km), TOTAL_ROUTE_KM))
}

# ── waypoints.csv: keep the hand-curated rows, refresh route_deg ──────────────

wp <- read_csv(WAYPOINTS_CSV, show_col_types = FALSE)
wp$route_deg <- round(route_bearing(trk, wp$km), 1)

snapped <- vapply(seq_len(nrow(wp)), function(i) {
  trk$km[which.min(haversine(wp$lat[i], wp$lon[i], trk$lat, trk$lon))]
}, numeric(1))
off <- abs(snapped - wp$km) > 0.5
if (any(off)) {
  warning("Waypoint km disagrees with its coordinates on the track: ",
          paste(sprintf("%s (km %.1f, track says %.1f)",
                        wp$name[off], wp$km[off], snapped[off]), collapse = "; "))
}

write_csv(wp, WAYPOINTS_CSV)
cat("Wrote", WAYPOINTS_CSV, "-", nrow(wp), "waypoints with route_deg\n")

# ── route_directions.csv: distance-weighted travel-direction histogram ────────
# Two exclusions: the Kuivastu–Virtsu gap goes as any step over 3 km, but the
# other two crossings are drawn across the water at ~100 m steps and can only
# be dropped by km range — otherwise 37 km of open sea would count as riding
# in whatever direction the crossings happen to run.

dir_hist <- trk |>
  mutate(brg = c(NA, bearing(head(lat, -1), head(lon, -1), tail(lat, -1), tail(lon, -1)))) |>
  filter(step > 0, step < 3000, !in_ferry, !is.na(brg)) |>
  mutate(deg = round(brg) %% 360) |>
  group_by(deg) |>
  summarise(km = round(sum(step) / 1000, 4), .groups = "drop") |>
  arrange(deg)

write_csv(dir_hist, ROUTE_DIRECTIONS_CSV)
cat("Wrote", ROUTE_DIRECTIONS_CSV, "-", nrow(dir_hist), "bins,",
    sprintf("%.1f km ridden\n", sum(dir_hist$km)))
