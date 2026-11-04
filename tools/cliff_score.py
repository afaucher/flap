"""The cliff's scorecard: the concept's numbers (the targets) against ours, from the reports tools/cliff_measure.ps1 writes.

    python tools/cliff_score.py <measure out dir>

Reads <dir>/zones/{concept,model}_segments.json (cliff_segment.py), <dir>/shapes/shapes_report.json (cliff_shapes.py)
and <dir>/sections/sections_report.json (cliff_section.py: concept_* and ours_* cuts), prints one table and writes
<dir>/score.md and score.json. Each row says how far to trust it: "along" rows (lengths and headings along the cliff,
from the concept's plan picture) and "section" rows (the cross-sections) compare like with like; "across" rows (depths,
shares and headings from the plan picture) don't, because that picture is the front view's layout redrawn from above -- its
up-down axis is mostly the cliff's height, not depth out from it (docs/design/cliff_from_concept.md) -- so they're
shown for reference only and never fail.
"""
import json
import os
import sys

import numpy as np


def get(d, path):
    for k in path.split("."):
        if not isinstance(d, dict) or k not in d:
            return None
        d = d[k]
    return d


def mean_of(reps, prefix, key):
    v = [r[key] for n, r in reps.items() if n.startswith(prefix) and r.get(key) is not None]
    return float(np.mean(v)) if v else None


# (label, trust, source, key, tolerance: "deg:<n>" degrees either way, "abs:<n>" n either way, "rel:<f>" a share of the
# target either way, "zero:<n>" at most n)
ROWS = [
    ("Edges: heading off the cliff's line, ledge back (deg)", "across", "shapes", "ledge_back.heading_abs_deg", None),
    ("Edges: heading off the cliff's line, ledge lip (deg)", "across", "shapes", "ledge_lip.heading_abs_deg", None),
    ("Edges: heading off the cliff's line, wall foot (deg)", "across", "shapes", "wall_foot.heading_abs_deg", None),
    ("Edges across the cliff (m per 100 m)", "along", "shapes", "talus_over_face.m_per_100m", "zero:10"),
    ("Edges: median run, ledge back (m)", "along", "shapes", "ledge_back.run_median_m", "rel:0.4"),
    ("Edges: median run, ledge lip (m)", "along", "shapes", "ledge_lip.run_median_m", "rel:0.4"),
    ("Edges: median run, wall foot (m)", "along", "shapes", "wall_foot.run_median_m", "rel:0.5"),
    ("Edges: straight between corners, ledge lip (m)", "along", "shapes", "ledge_lip.straight_m", "rel:0.3"),
    ("Ledges: median length (m)", "along", "shapes", "ledges.length.median", "rel:0.3"),
    ("Ledges: ends to half depth (share of length)", "along", "shapes", "ledges.ends_to_half.median", "rel:0.5"),
    ("Section: face, height-weighted angle (deg)", "section", "sections", "face_deg_height_weighted", "deg:4"),
    ("Section: face, lip to foot (deg)", "section", "sections", "face_deg_lip_to_foot", "deg:10"),
    ("Section: whole cliff, lip to toe (deg)", "section", "sections", "overall_deg", "deg:6"),
    ("Section: face overhanging (share of its height)", "section", "sections", "face_share_overhanging", "abs:0.07"),
    ("Section: talus angle (deg)", "section", "sections", "talus_deg", "deg:4"),
    ("Section: talus buries (share of height)", "section", "sections", "talus_buries", "rel:0.25"),
    ("Section: talus reach (share of height)", "section", "sections", "talus_reach", "rel:0.25"),
    ("Zones: face share", "across", "zones", "face_share", None),
    ("Zones: flat ground and ledge share", "across", "zones", "flat_share", None),
    ("Zones: talus share", "across", "zones", "talus_share", None),
    ("Ledges: median depth (m)", "across", "shapes", "ledges.depth.median", None),
    ("Ledges: fullness (area over length x depth)", "across", "shapes", "ledges.fullness.median", None),
]


def verdict(target, ours, tol):
    if tol is None or target is None or ours is None:
        return "ref"
    kind, n = tol.split(":")
    n = float(n)
    if kind == "deg":
        return "ok" if abs(ours - target) <= n else ("high" if ours > target else "low")
    if kind == "zero":
        return "ok" if ours <= n else "high"
    if kind == "abs":
        return "ok" if abs(ours - target) <= n else ("high" if ours > target else "low")
    return "ok" if abs(ours - target) <= abs(target) * n else ("high" if ours > target else "low")


def main():
    d = sys.argv[1]
    zones = {k: json.load(open(os.path.join(d, "zones", k + "_segments.json"))) for k in ("concept", "model")}
    shapes = json.load(open(os.path.join(d, "shapes", "shapes_report.json")))
    sections = json.load(open(os.path.join(d, "sections", "sections_report.json")))
    rows = []
    for label, trust, src, key, tol in ROWS:
        if src == "sections":
            t, o = mean_of(sections, "concept", key), mean_of(sections, "ours", key)
        elif src == "shapes":
            t, o = get(shapes.get("concept", {}), key), get(shapes.get("model", {}), key)
            if key.startswith("talus_over_face"):
                t = t or 0.0
                o = o or 0.0
        else:
            t, o = get(zones["concept"], key), get(zones["model"], key)
        rows.append({"what": label, "trust": trust, "concept": t, "ours": o, "verdict": verdict(t, o, tol)})
    fmt = lambda v: "-" if v is None else ("%.2f" % v if abs(v) < 10 else "%.1f" % v)
    lines = ["| What | Trust | Concept | Ours | |", "|---|---|---|---|---|"]
    for r in rows:
        lines.append("| %s | %s | %s | %s | %s |" % (r["what"], r["trust"], fmt(r["concept"]), fmt(r["ours"]), r["verdict"]))
    scored = [r for r in rows if r["verdict"] != "ref"]
    ok = sum(r["verdict"] == "ok" for r in scored)
    lines.append("")
    lines.append("%d of %d scored rows within tolerance." % (ok, len(scored)))
    text = "\n".join(lines)
    print(text)
    open(os.path.join(d, "score.md"), "w", encoding="utf-8").write(text + "\n")
    json.dump({"rows": rows, "ok": ok, "scored": len(scored)}, open(os.path.join(d, "score.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
