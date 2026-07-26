# Kõkõva 900 (2026) — report pipeline.
# Run from the project root. `make` refreshes everything that changes daily.

R := Rscript

TRACK := data/kokova_2026_900_beta.kmz
# prepare_route.R writes waypoints.csv and route_directions.csv in one pass, so
# waypoints.csv stands in for the pair. Listing both as targets of one rule would
# run the recipe once per file, and grouped targets (&:) need make 4.3 while
# macOS still ships 3.81.
ROUTE := data/waypoints.csv

.PHONY: all daily ferry forecast outlook route resupply surface strategy recon clean-reports

# The daily targets. The climatology outlook is deliberately excluded: it reads
# ten years of ERA5 and its numbers barely move, so it is a manual step. So is
# resupply, which hammers Overpass and only changes when the route does.
daily: ferry forecast strategy

all: route resupply surface daily outlook

# The fetch steps are phony on purpose. Their output depends on what the ferry
# operators and weather models say right now, not on any file, so timestamp
# logic would skip them exactly when they are needed — and after a fresh CI
# checkout every file carries the same mtime, making that skip unpredictable.
ferry:
	$(R) R/ferry_schedule.R

forecast: route
	$(R) R/weather_forecast.R

outlook: route
	$(R) R/weather_outlook.R

# Route geometry is the one genuine file dependency: it is derived from the
# track rather than fetched, so it rebuilds only when a new KMZ lands.
route: $(ROUTE)

$(ROUTE): $(TRACK) R/prepare_route.R R/plan.R
	$(R) R/prepare_route.R

# Resupply is route-derived too, but kept out of `route` so a track refresh does
# not fire ~10 throttled Overpass queries unless asked.
resupply: data/resupply.csv

data/resupply.csv: $(TRACK) R/resupply.R R/plan.R
	$(R) R/resupply.R

# Strategy is part of `daily`: it embeds ferry times, which move with the
# timetable, so a stale strategy report would quietly contradict ferry_plan.md.
# It only reads local files, so it costs nothing to rerun.
# No file prerequisite on data/resupply.csv on purpose: it is committed, and
# declaring it here would let a fresh CI checkout's uniform mtimes decide to
# rebuild it, firing ten throttled Overpass queries inside the daily job. Both
# scripts fail with a clear message if the CSV is genuinely missing.
strategy:
	$(R) R/race_strategy.R
	$(R) R/resupply_plan.R

# Surface needs a ~120 MB Geofabrik extract, cached under cache/ and gitignored.
surface: data/surface.csv

data/surface.csv: $(TRACK) R/surface.R R/plan.R
	$(R) R/surface.R

# One-off plan for the 29-31 Jul recon ride; regenerate if the route changes.
recon:
	$(R) R/recon_ride.R

clean-reports:
	rm -f reports/*.md output/*.json
