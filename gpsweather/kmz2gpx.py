"""Convert a KMZ/KML track (LineString placemarks) to GPX for routewx_multiday.

Each LineString becomes one <trkseg>, in document order. Note load_gpx flattens
all trkpt, so gaps between segments (e.g. ferry legs) are bridged as ridden
distance — handle ferries in the model, not here.

Usage: python kmz2gpx.py input.kmz output.gpx
"""

import sys
import zipfile
import xml.etree.ElementTree as ET

KML_NS = "{http://www.opengis.net/kml/2.2}"


def read_kml(path: str) -> str:
    if path.lower().endswith(".kmz"):
        with zipfile.ZipFile(path) as z:
            name = next(n for n in z.namelist() if n.lower().endswith(".kml"))
            return z.read(name).decode("utf-8")
    with open(path, encoding="utf-8") as f:
        return f.read()


def linestrings(kml_text: str):
    root = ET.fromstring(kml_text)
    for pm in root.iter(f"{KML_NS}Placemark"):
        name_el = pm.find(f"{KML_NS}name")
        name = name_el.text if name_el is not None else ""
        for ls in pm.iter(f"{KML_NS}LineString"):
            coords = ls.find(f"{KML_NS}coordinates")
            if coords is None or not coords.text:
                continue
            pts = []
            for tok in coords.text.split():
                parts = tok.split(",")
                lon, lat = float(parts[0]), float(parts[1])
                ele = float(parts[2]) if len(parts) > 2 else None
                pts.append((lat, lon, ele))
            yield name, pts


def main():
    src, dst = sys.argv[1], sys.argv[2]
    segs = list(linestrings(read_kml(src)))
    if not segs:
        sys.exit(f"no LineString found in {src}")

    out = ['<?xml version="1.0" encoding="UTF-8"?>',
           '<gpx version="1.1" creator="kmz2gpx" xmlns="http://www.topografix.com/GPX/1/1">',
           "<trk><name>converted</name>"]
    n_pts = 0
    for name, pts in segs:
        out.append("<trkseg>")
        for lat, lon, ele in pts:
            e = f"<ele>{ele:.1f}</ele>" if ele is not None else ""
            out.append(f'<trkpt lat="{lat:.6f}" lon="{lon:.6f}">{e}</trkpt>')
            n_pts += 1
        out.append("</trkseg>")
    out += ["</trk>", "</gpx>"]

    with open(dst, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print(f"{len(segs)} segment(s), {n_pts} points -> {dst}")
    for name, pts in segs:
        print(f"  {name}: {len(pts)} pts")


if __name__ == "__main__":
    main()
