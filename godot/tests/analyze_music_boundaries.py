"""Inspect PCM16 Music Bus captures; listening is a separate acceptance step."""
import array
import json
import math
from pathlib import Path
import wave

EVIDENCE = Path(__file__).resolve().parents[1] / "docs/reports/music-states-evidence"


def analyze(path):
    with wave.open(str(path)) as capture:
        assert capture.getsampwidth() == 2
        samples = array.array("h", capture.readframes(capture.getnframes()))
        rate = capture.getframerate() * capture.getnchannels()
    window = rate // 100
    rms = [math.sqrt(sum(x * x for x in samples[i:i + window]) / len(samples[i:i + window])) / 32768
           for i in range(0, len(samples), window)]
    interior = rms[20:-20]
    return {
        "duration_seconds": len(samples) / rate,
        "peak_dbfs": 20 * math.log10(max(max(abs(x) for x in samples) / 32768, 1e-9)),
        "minimum_interior_10ms_rms_dbfs": 20 * math.log10(max(min(interior), 1e-9)),
        "zero_interior_10ms_windows": sum(x == 0 for x in interior),
        "clipped_samples": sum(abs(x) >= 32767 for x in samples),
    }


if __name__ == "__main__":
    result = {path.name: analyze(path) for path in sorted(EVIDENCE.glob("*-boundary.wav"))}
    full = Path("/tmp/metal-road-music-full-loop.wav")
    if full.exists():
        result[full.name] = analyze(full)
    output = json.dumps(result, indent=2) + "\n"
    (EVIDENCE / "boundary-analysis.json").write_text(output)
    print(output)
