#!/usr/bin/env python3
"""Generate the original adaptive arena theme "Foundry Verdict".

The three sample-accurate stems share one 172 BPM timeline and are designed to
loop together. No external samples or copyrighted melodies are used.
"""

from __future__ import annotations

import math
import subprocess
import wave
from pathlib import Path

import numpy as np


RATE = 44_100
BPM = 172.0
BEAT = 60.0 / BPM
STEP = BEAT / 4.0
BARS = 32
STEPS = BARS * 16
DURATION = STEPS * STEP
FRAMES = int(round(DURATION * RATE))
ROOT_HZ = 65.406  # C2, low and heavy without masking vehicle impacts.
RNG = np.random.default_rng(918_221)


def buffer() -> np.ndarray:
    return np.zeros((FRAMES, 2), dtype=np.float32)


def envelope(length: int, attack: float, release: float, decay: float = 0.0) -> np.ndarray:
    env = np.ones(length, dtype=np.float32)
    attack_n = min(length, max(1, int(attack * RATE)))
    release_n = min(length, max(1, int(release * RATE)))
    env[:attack_n] *= np.linspace(0.0, 1.0, attack_n, dtype=np.float32)
    env[-release_n:] *= np.linspace(1.0, 0.0, release_n, dtype=np.float32)
    if decay > 0.0:
        env *= np.exp(-np.linspace(0.0, decay, length, dtype=np.float32))
    return env


def add(target: np.ndarray, sound: np.ndarray, start: float, gain: float = 1.0) -> None:
    index = int(round(start * RATE))
    if index >= FRAMES:
        return
    end = min(FRAMES, index + len(sound))
    target[index:end] += sound[: end - index] * gain


def one_pole(signal: np.ndarray, coefficient: float) -> np.ndarray:
    out = np.empty_like(signal)
    state = 0.0
    for i, value in enumerate(signal):
        state += coefficient * (float(value) - state)
        out[i] = state
    return out


def power_chord(semitones: int, duration: float, palm: bool = True, accent: float = 1.0) -> np.ndarray:
    length = max(8, int(duration * RATE))
    t = np.arange(length, dtype=np.float32) / RATE
    root = ROOT_HZ * (2.0 ** (semitones / 12.0))

    def string(freq: float, detune: float) -> np.ndarray:
        phase = 2.0 * np.pi * freq * (1.0 + detune) * t
        wave_sum = np.zeros(length, dtype=np.float32)
        for harmonic in range(1, 9):
            wave_sum += np.sin(phase * harmonic + harmonic * 0.17) / (harmonic ** 0.72)
        return wave_sum

    left = string(root, -0.0018) + 0.72 * string(root * 1.4983, -0.0012) + 0.48 * string(root * 2.0, -0.0008)
    right = string(root, 0.0019) + 0.72 * string(root * 1.5017, 0.0011) + 0.48 * string(root * 2.0, 0.0009)
    grit = RNG.normal(0.0, 0.05, length).astype(np.float32)
    left += grit
    right += np.roll(grit, 17)
    drive = 2.9 if palm else 2.25
    left = np.tanh(left * drive)
    right = np.tanh(right * drive)
    # Crude cabinet: remove fizzy ultrasonic content while keeping pick attack.
    left = one_pole(left, 0.19)
    right = one_pole(right, 0.19)
    env = envelope(length, 0.003, 0.028 if palm else 0.12, 5.2 if palm else 1.35)
    return np.column_stack((left, right)) * env[:, None] * (0.22 * accent)


def bass_note(semitones: int, duration: float, accent: float = 1.0) -> np.ndarray:
    length = max(8, int(duration * RATE))
    t = np.arange(length, dtype=np.float32) / RATE
    freq = ROOT_HZ * 0.5 * (2.0 ** (semitones / 12.0))
    phase = 2.0 * np.pi * freq * t
    raw = np.sin(phase) + 0.44 * np.sin(phase * 2.0) + 0.2 * np.sin(phase * 3.0)
    raw = np.tanh(raw * 1.8)
    env = envelope(length, 0.006, 0.06, 1.3)
    mono = raw * env * 0.34 * accent
    return np.column_stack((mono, mono))


def kick(accent: float = 1.0) -> np.ndarray:
    length = int(0.24 * RATE)
    t = np.arange(length, dtype=np.float32) / RATE
    phase = 2.0 * np.pi * (48.0 * t + (112.0 - 48.0) * (1.0 - np.exp(-t * 35.0)) / 35.0)
    body = np.sin(phase) * np.exp(-t * 18.0)
    click = RNG.normal(0.0, 1.0, length).astype(np.float32) * np.exp(-t * 95.0)
    mono = np.tanh((body * 1.8 + click * 0.17) * 1.4) * 0.62 * accent
    return np.column_stack((mono, mono))


def snare(accent: float = 1.0) -> np.ndarray:
    length = int(0.28 * RATE)
    t = np.arange(length, dtype=np.float32) / RATE
    noise = RNG.normal(0.0, 1.0, length).astype(np.float32)
    bright = noise - one_pole(noise, 0.06)
    tone = np.sin(2.0 * np.pi * 188.0 * t) * np.exp(-t * 16.0)
    mono = np.tanh((bright * np.exp(-t * 13.0) * 0.62 + tone * 0.45) * 1.45) * 0.42 * accent
    return np.column_stack((mono, np.roll(mono, 9)))


def hat(open_hat: bool = False, pan: float = 0.0) -> np.ndarray:
    duration = 0.24 if open_hat else 0.075
    length = int(duration * RATE)
    t = np.arange(length, dtype=np.float32) / RATE
    noise = RNG.normal(0.0, 1.0, length).astype(np.float32)
    high = noise - one_pole(noise, 0.035)
    mono = high * np.exp(-t * (15.0 if open_hat else 58.0)) * (0.14 if open_hat else 0.09)
    return np.column_stack((mono * (1.0 - max(0.0, pan)), mono * (1.0 + min(0.0, pan))))


def metal_hit(pitch: float = 1.0, pan: float = 0.0) -> np.ndarray:
    length = int(0.42 * RATE)
    t = np.arange(length, dtype=np.float32) / RATE
    freqs = np.array([411.0, 623.0, 907.0, 1277.0]) * pitch
    mono = sum(np.sin(2.0 * np.pi * f * t + i * 0.8) for i, f in enumerate(freqs))
    mono += RNG.normal(0.0, 0.35, length)
    mono = np.tanh(mono * 1.3) * np.exp(-t * 8.5) * 0.13
    return np.column_stack((mono * (1.0 - max(0.0, pan)), mono * (1.0 + min(0.0, pan))))


def siren(duration: float, rise: bool) -> np.ndarray:
    length = int(duration * RATE)
    t = np.arange(length, dtype=np.float32) / RATE
    progress = t / max(duration, 0.001)
    start, end = ((92.0, 138.0) if rise else (138.0, 92.0))
    freq = start + (end - start) * progress + np.sin(t * 2.0 * np.pi * 0.5) * 5.0
    phase = 2.0 * np.pi * np.cumsum(freq) / RATE
    mono = (np.sin(phase) + 0.32 * np.sin(phase * 2.01)) * envelope(length, 0.18, 0.3, 0.15) * 0.12
    return np.column_stack((mono, np.roll(mono, 31)))


def compose() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    base, combat, boss = buffer(), buffer(), buffer()
    riffs = [
        [0, None, 0, 0, 3, None, 0, 5, 0, 0, None, 6, 5, None, 3, 0],
        [0, 0, None, 3, 0, None, 6, 5, 0, None, 0, 8, 6, 5, 3, None],
        [0, None, 0, 1, 0, None, 5, 3, 0, 0, 6, None, 5, 3, 1, None],
        [0, 0, 0, None, 8, 6, 5, None, 0, 3, 0, None, 6, 5, 3, 1],
    ]
    kick_patterns = [[0, 3, 7, 8, 11, 14], [0, 2, 6, 8, 10, 15], [0, 3, 5, 8, 11, 13, 15], [0, 2, 7, 8, 10, 14, 15]]

    for bar in range(BARS):
        section = (bar // 8) % 4
        riff = riffs[section]
        bar_start = bar * 16 * STEP
        for step, note in enumerate(riff):
            when = bar_start + step * STEP
            if note is not None:
                long_note = step in (7, 15) and section in (1, 3)
                duration = STEP * (2.7 if long_note else 1.15)
                accent = 1.22 if step in (0, 8) else 0.92
                add(base, power_chord(note, duration, not long_note, accent), when)
                add(base, bass_note(note, duration * 1.12, accent), when)
        for step in kick_patterns[section]:
            add(base, kick(1.15 if step in (0, 8) else 0.92), bar_start + step * STEP)
        for step in (4, 12):
            add(base, snare(1.08 if step == 12 else 1.0), bar_start + step * STEP)
        for step in range(0, 16, 2):
            add(base, hat(step == 14, -0.25 if step % 4 == 0 else 0.22), bar_start + step * STEP)
        if bar % 2 == 1:
            add(base, metal_hit(0.82 + section * 0.08, -0.4 if bar % 4 == 1 else 0.4), bar_start + 15 * STEP)

        # Combat layer: rapid kick runs, answering guitar and scrap percussion.
        combat_kicks = [1, 2, 5, 6, 9, 10, 13, 14, 15] if bar % 2 == 0 else [2, 3, 6, 7, 10, 11, 14, 15]
        for step in combat_kicks:
            add(combat, kick(0.62), bar_start + step * STEP)
        answer_notes = [12, 12, 10, 8] if section in (0, 2) else [7, 8, 10, 6]
        for index, step in enumerate((2, 6, 10, 14)):
            add(combat, power_chord(answer_notes[index], STEP * 1.45, True, 0.7), bar_start + step * STEP)
        for step in (3, 7, 11, 15):
            add(combat, metal_hit(1.2 + (step % 3) * 0.09, -0.55 if step in (3, 11) else 0.55), bar_start + step * STEP, 0.8)

        # Boss layer: a compatible half-time breakdown plus low industrial siren.
        boss_pattern = [0, None, 0, None, 1, None, 0, 0, 6, None, 5, None, 3, 1, 0, None]
        for step, note in enumerate(boss_pattern):
            if note is not None:
                add(boss, power_chord(note - 12 if note == 0 else note, STEP * 1.55, True, 0.78), bar_start + step * STEP)
        for step in (0, 7, 8, 10, 15):
            add(boss, kick(0.86), bar_start + step * STEP)
        add(boss, snare(0.82), bar_start + 8 * STEP)
        if bar % 4 == 0:
            add(boss, siren(4 * 16 * STEP, (bar // 4) % 2 == 0), bar_start)

    return base, combat, boss


def master(stem: np.ndarray, peak: float) -> np.ndarray:
    # Gentle glue compression, 12 ms fades only to suppress encoder edge ticks.
    stem = np.tanh(stem * 1.25)
    current = float(np.max(np.abs(stem)))
    if current > 0.0:
        stem *= peak / current
    edge = min(int(0.012 * RATE), len(stem) // 4)
    fade = np.linspace(0.0, 1.0, edge, dtype=np.float32)
    stem[:edge] *= fade[:, None]
    stem[-edge:] *= fade[::-1, None]
    return stem


def write_wav(path: Path, stem: np.ndarray) -> None:
    pcm = np.clip(stem, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def main() -> None:
    output = Path(__file__).resolve().parents[1] / "assets" / "music"
    output.mkdir(parents=True, exist_ok=True)
    stems = compose()
    for name, stem, peak in zip(("base", "combat", "boss"), stems, (0.88, 0.78, 0.8)):
        wav_path = output / f"foundry_verdict_{name}.wav"
        ogg_path = output / f"foundry_verdict_{name}.ogg"
        write_wav(wav_path, master(stem, peak))
        subprocess.run(
            ["ffmpeg", "-y", "-v", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "5", str(ogg_path)],
            check=True,
        )
        wav_path.unlink()
    print(f"Generated three {DURATION:.3f}s OGG stems at {BPM:.0f} BPM")


if __name__ == "__main__":
    main()
