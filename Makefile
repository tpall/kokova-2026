# Kõkõva 900 (2026) — report pipeline.
# Run from the project root. `make` refreshes everything that changes daily.

R := Rscript

TRACK := data/kokova_2026_900_beta.kmz
# prepare_route.R writes waypoints.csv and route_directions.csv in one pass, so
# waypoints.csv stands in for the pair. Listing both as targets of one rule would
# run the recipe once per file, and grouped targets (&:) need make 4.3 while
# macOS still ships 3.81.
ROUTE := data/waypoints.csv

.PHONY: all daily ferry forecast outlook route clean-reports

# The daily targets. The climatology outlook is deliberately excluded: it reads
# ten years of ERA5 and its numbers barely move, so it is a manual step.
daily: ferry forecast

all: route daily outlook

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

clean-reports:
	rm -f reports/*.md output/*.json
