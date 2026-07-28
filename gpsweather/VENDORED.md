# Vendored from ~/Projects/gps-weather @ 604e64d

Generic route-weather engine (any GPX/KMZ + rider JSON + optional ferries
JSON). Do NOT edit here — develop in the gps-weather project and re-copy:

    cp ~/Projects/gps-weather/{routewx_multiday,kmz2gpx,outlook}.py \
       ~/Projects/gps-weather/data/rider_taavi.json gpsweather/

Deps: numpy, requests (see the workflow's pip step). When gps-weather gets
a GitHub remote, replace this directory with a checkout step in the GA.
