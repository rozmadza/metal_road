# Original UI sounds

menu_hover.wav — 65 ms restrained metallic tick.
menu_click.wav — 160 ms low mechanical latch with a short metallic overtone.
Mono, 44.1 kHz, PCM 16 bit; original deterministic synthesis, no sampled material.
Regenerate: `python3 tools/generate_ui_audio.py`.

Streams and level are configured in resources/audio/menu_audio.tres (AudioConfig).
UISounds uses the UI bus. Clear either stream to disable that cue.
Clicks survive scene changes briefly and free on completion or timeout.
Music and gameplay audio replacement are Phase I work.
