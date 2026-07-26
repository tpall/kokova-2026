# Kõkõva 900 (2026) — derive the committed route files from the KMZ.
#
# Run this once whenever a new track arrives, then commit the two CSVs it
# writes. The KMZ itself is the organiser's unreleased BETA file and is NOT
# committed (see .gitignore), so every other script depends only on these
# derivatives and the repo works without the track present.
#
#   waypoints.csv        21 waypoints: km, name, coordinates, elevation, type,
#                        and the direction of travel at that point
#   route_directions.csv distance-weighted histogram of travel direction over
#                        the whole route, 1° bins — what the wind-exposure
#                        calculation in weather_outlook.R needs
#
# Waypoint names are hand-curated (reverse geocoding returns bare municipality
# names for much of Saaremaa), so this script preserves the existing names and
# only recomputes the geometry.
#
# Run: Rscript prepare_route.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("kokova_plan.R")

if (!file.exists(KMZ_FILE)) {
  stop("Need ", KMZ_FILE, " to regenerate the route files. It is deliberately\n",
       "  not committed — get it from the organiser and place it in the project root.")
}

trk <- read_track()
cat(sprintf("Track: %.1f km over %d points\n", max(trk$km), nrow(trk)))

# ── waypoints.csv: keep names and km, refresh geometry ────────────────────────

wp <- read_csv(WAYPOINTS_CSV, show_col_types = FALSE)
wp$route_deg <- round(route_bearing(trk, wp$km), 1)
write_csv(wp, WAYPOINTS_CSV)
cat("Wrote", WAYPOINTS_CSV, "-", nrow(wp), "waypoints with route_deg\n")

# ── route_directions.csv: distance-weighted travel-direction histogram ────────
# Ferry legs are dropped: two of the three appear as a multi-km jump between
# LineStrings, which would otherwise register as a long straight in whatever
# direction the crossing happens to run.

dir_hist <- trk |>
  filter(step > 0, step < 3000) |>
  mutate(brg = c(NA, bearing(head(lat, -1), head(lon, -1), tail(lat, -1), tail(lon, -1)))) |>
  filter(!is.na(brg)) |>
  mutate(deg = round(brg) %% 360) |>
  group_by(deg) |>
  summarise(km = round(sum(step) / 1000, 4), .groups = "drop") |>
  arrange(deg)

write_csv(dir_hist, ROUTE_DIRECTIONS_CSV)
cat("Wrote", ROUTE_DIRECTIONS_CSV, "-", nrow(dir_hist), "bins,",
    sprintf("%.1f km ridden\n", sum(dir_hist$km)))
