"""Summarize rendered audit JSON. Standard library only; no game changes."""
import argparse
import csv
import json
import math
from pathlib import Path
from statistics import mean


def quantile(values, q):
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * q) - 1)] if ordered else None


def describe(values):
    return {"n": len(values), "mean": mean(values) if values else None,
            "p95": quantile(values, .95), "p99": quantile(values, .99),
            "max": max(values) if values else None}


def analyze(folder):
    summaries, functions, events = [], [], []
    for manifest_path in sorted(folder.glob("*-manifest.json")):
        manifest = json.loads(manifest_path.read_text())
        run_id = manifest["id"]
        if run_id == "pilot":
            continue
        for window in manifest["windows"]:
            data = json.loads((folder / window["file"]).read_text())
            rows = data["frames"]
            if not rows:
                continue
            start_us = rows[0][0] - rows[0][1] * 1000
            # Native process/physics monitors are last-second maxima. Their
            # old setup-window maxima can persist into the next scenario.
            settled = [r for r in rows if r[0] - start_us >= 2_000_000]
            wall = [r[1] for r in rows]
            impact_indices = [i for i, r in enumerate(rows) if r[13] > 0]
            near_impacts = {j for i in impact_indices
                            for j in range(max(0, i-2), min(len(rows), i+3))}
            row = {
                "run": run_id, "phase": data["phase"],
                "instrumented": manifest["instrumented"], "vsync": manifest["vsync"],
                "collector": manifest.get("collector_version", 1),
                "wall_s": data["metrics"]["elapsed_wall_s"],
                "frames": len(rows), "fps": 1000 / mean(wall),
                "frame_ms": describe(wall),
                "gpu_ms": describe([r[5] for r in rows]),
                "render_cpu_ms": describe([r[4] for r in rows]),
                "physics_1s_peak_ms_after_2s": max((r[3] for r in settled), default=None),
                "process_1s_peak_ms_after_2s": max((r[2] for r in settled), default=None),
                "ai_min": min(r[9] for r in rows), "ai_mean": mean(r[9] for r in rows),
                "ai_max": max(r[9] for r in rows),
                "projectiles_max": max(r[10] for r in rows),
                "vfx_max": max(r[11] for r in rows),
                "nodes_max": max(r[12] for r in rows),
                "draw_calls_max": max(r[6] for r in rows),
                "collision_pairs_max": max(r[8] for r in rows),
                "impact_signals": sum(r[13] for r in rows),
                "max_frame_near_impact_ms": max((rows[i][1] for i in near_impacts), default=None),
                "over_16_67ms": sum(v > 1000/60 for v in wall),
                "over_33_33ms": sum(v > 1000/30 for v in wall),
                "over_100ms": sum(v > 100 for v in wall),
                "probe_us": describe([r[18] for r in rows]),
                "metrics": data["metrics"],
            }
            summaries.append(row)
        for key, durations in manifest.get("function_times_us", {}).items():
            phase, function = key.split("::", 1)
            functions.append({"run": run_id, "phase": phase, "function": function,
                              "total_ms": sum(durations)/1000,
                              "us": describe(durations)})
        events.extend(dict(event, run=run_id) for event in manifest.get("slow_events", []))
    return {"windows": summaries, "functions": functions, "slow_events": events}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("folders", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = {"windows": [], "functions": [], "slow_events": []}
    for folder in args.folders:
        data = analyze(folder)
        for key in result:
            result[key].extend(data[key])
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "summary.json").write_text(json.dumps(result, indent=2))
    fields = ["run", "phase", "wall_s", "frames", "fps", "mean_ms", "p95_ms", "p99_ms", "max_ms",
              "physics_1s_peak_ms_after_2s", "ai_min", "ai_mean", "ai_max", "projectiles_max", "vfx_max",
              "over_16_67ms", "over_33_33ms", "over_100ms", "gpu_mean_ms", "gpu_p99_ms", "instrumented"]
    with (args.output / "windows.csv").open("w", newline="") as output:
        writer = csv.DictWriter(output, fields)
        writer.writeheader()
        for row in result["windows"]:
            item = {key: row.get(key) for key in fields}
            for key in ["mean", "p95", "p99", "max"]:
                item[key+"_ms"] = row["frame_ms"][key]
            item["gpu_mean_ms"] = row["gpu_ms"]["mean"]
            item["gpu_p99_ms"] = row["gpu_ms"]["p99"]
            writer.writerow(item)
    print(f"Analyzed {len(result['windows'])} rendered windows, {len(result['functions'])} timing groups")


if __name__ == "__main__":
    main()
