#!/usr/bin/env python3
"""Summarise raw graphical BonusPickup measurements (nearest-rank percentiles)."""
import bisect
import json
import math
import pathlib
import sys
from collections import defaultdict

root = pathlib.Path(sys.argv[1])


def stats(values):
    if not values:
        return None
    ordered = sorted(values)
    return {
        "n": len(ordered),
        "mean": sum(ordered) / len(ordered),
        "p95": ordered[math.ceil(0.95 * len(ordered)) - 1],
        "p99": ordered[math.ceil(0.99 * len(ordered)) - 1],
        "max": ordered[-1],
    }


summary = {}
for manifest_path in sorted(root.glob("bonus-*-manifest.json")):
    run_id = manifest_path.name.removesuffix("-manifest.json")
    manifest = json.loads(manifest_path.read_text())
    stages_path = root / f"{run_id}-stages.json"
    stages = json.loads(stages_path.read_text())["events"] if stages_path.exists() else []
    natural = [e for e in stages if e["phase"] != "forced_types_fixture"]
    grouped = defaultdict(list)
    for e in natural:
        if "us" in e:
            key = e["stage"]
            if key == "weapon_load":
                key += "_" + e["detail"].split(":")[0]
            grouped[key].append(e["us"] / 1000.0)
    windows = {}
    for window in manifest["windows"]:
        payload = json.loads((root / window["file"]).read_text())
        frames = payload["frames"]
        frame_times = [frame[1] for frame in frames[1:]]
        stamps = [frame[0] for frame in frames]
        nearest_events = []
        for event in natural:
            if event["stage"] != "total" or event["phase"] != window["label"]:
                continue
            i = bisect.bisect_left(stamps, event["at_us"])
            if i < len(frames):
                nearest_events.append({"id": event["id"], "create_ms": event["us"] / 1000.0,
                    "frame_ms": frames[i][1], "ai": frames[i][9], "time_s": (event["at_us"] - stamps[0]) / 1e6})
        windows[window["label"]] = {
            "frame": stats(frame_times),
            "gpu_ms": stats([frame[5] for frame in frames[1:]]),
            "active_ai_max": max(frame[9] for frame in frames),
            "create_frames": nearest_events,
            "duration_s": window["metrics"]["elapsed_wall_s"],
        }
    memory = {row["phase"]: {key: row[key] for key in
        ["rss_kb", "godot_static_bytes", "godot_video_bytes", "godot_texture_bytes", "resources"]}
        for row in manifest["setup_events"] if row["event"] == "memory"}
    summary[run_id] = {
        "windows": windows,
        "stages_ms": {key: stats(values) for key, values in sorted(grouped.items())},
        "forced_stages_ms": {key: stats([e["us"] / 1000.0 for e in stages
            if e["phase"] == "forced_types_fixture" and e["stage"] == key]) for key in
            ["position", "instantiate", "weapon_load", "ready.total", "tree_add_including_ready", "total"]},
        "memory": memory,
        "forced_spawns": [row for row in manifest["setup_events"] if row["event"] == "forced_spawn"],
    }

output = root / "summary.json"
output.write_text(json.dumps(summary, ensure_ascii=False, indent=2))
for run_id, row in summary.items():
    print(run_id)
    for name, window in row["windows"].items():
        frame = window["frame"]
        print(" ", name, "frames", frame["n"], "mean/p95/p99/max",
              *(round(frame[key], 3) for key in ["mean", "p95", "p99", "max"]),
              "AImax", window["active_ai_max"],
              "creates", [(e["id"], round(e["create_ms"], 3), round(e["frame_ms"], 3))
                          for e in window["create_frames"]])
    for name, value in row["stages_ms"].items():
        if name in ["total", "position", "weapon_load_cached", "weapon_load_uncached",
                    "instantiate", "tree_add_including_ready", "ready.total", "draw.first"]:
            print(" ", name, value)
