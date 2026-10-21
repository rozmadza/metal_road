"""Original short mechanical UI cues. Stdlib only; deterministic and reproducible."""
import math
import random
import struct
import wave
from pathlib import Path

DEST = Path(__file__).resolve().parents[1] / 'assets/sounds/ui'
DEST.mkdir(parents=True, exist_ok=True)
RATE = 44100
for name, duration in [('menu_hover', 0.065), ('menu_click', 0.16)]:
    rng = random.Random(41)
    data = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        attack = min(1, t / 0.002)
        if name == 'menu_hover':
            sample = (0.14 * math.sin(2 * math.pi * 1100 * t) + 0.10 * rng.uniform(-1, 1)) * math.exp(-t * 75)
        else:
            sample = (0.3 * math.sin(2 * math.pi * 170 * t) + 0.14 * math.sin(2 * math.pi * 690 * t) + 0.23 * rng.uniform(-1, 1) * math.exp(-t * 90)) * math.exp(-t * 35)
        tail = min(1, (duration - t) / 0.01)
        data.append(struct.pack('<h', int(max(-1, min(1, sample * attack * tail)) * 32767)))
    with wave.open(str(DEST / (name + '.wav')), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(b''.join(data))
