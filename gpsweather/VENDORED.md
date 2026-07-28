# Vendored from ~/Projects/gps-weather @ e8791f0

Generic route-weather engine (any GPX/KMZ + rider JSON + optional ferries
JSON). Do NOT edit here — develop in the gps-weather project and re-copy:

    cp ~/Projects/gps-weather/{routewx_multiday,kmz2gpx,outlook}.py \
       ~/Projects/gps-weather/RIDER.md \
       ~/Projects/gps-weather/data/rider_taavi.json gpsweather/

RIDER.md documents the rider JSON (schema, estimate vs calibrate paths).
Calibration tooling (calibrate_rider.py) lives in the source project only —
rider_taavi.json here is its committed output. Deps: numpy, requests (see
the workflow's pip step). When gps-weather gets a GitHub remote, replace
this directory with a checkout step in the GA.
