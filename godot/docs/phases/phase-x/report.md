# Phase X — Season 1: Rust Frontier biome and tracks

## Content

- `Frontier Express`: a wide high-speed 7 km-class circuit through abandoned oil fields.
- `Copper Ravine`: a technical 7 km-class circuit with linked radius corners.
- `Oil Cauldron`: a 1280×900 survival arena with a ring of six major cover structures.
- Three new career events: Red Line, Oil Cauldron and Copper Storm.
- Both frontier tracks joined the deterministic daily-contract rotation.

## Art direction

- Original raster ground and asphalt materials generated for the biome.
- Original six-prop raster atlas: pumpjack, water tower, broken pipeline, drilling truck, checkpoint and drum/scrap pile.
- Atlas props are exported as six tightly cropped individual sprites and fitted with uniform scale, so no arena object is stretched or clipped.
- Warm ochre desert surround, cool charcoal road and restrained orange/teal navigation accents keep vehicles readable.
- New assets are strictly top-down and avoid vector placeholders.
- Collision cover uses a cool dark footprint and short amber safety corners: earth-coloured rocks and scrap remain visible without enclosing every prop in a heavy frame.

## Gameplay

- Periodic dust storm visibly sweeps across the screen and temporarily lowers traction/steering.
- Sand drifts, oil patches, explosive barrels and destructible crates form risk/reward lines.
- Track bonus hotspots provide five authored pickup zones per circuit.
- One visual lane per participant remains enforced; all six starting positions stay on the track.
- Frontier arena loads from career before scene initialization and has its own weather, cover and hazards.
- A low industrial two-note pulse and dust layer give the biome a distinct adaptive audio profile.

## Validation

- `frontier_biome_smoke.gd`: resources, length, weather, hazards, grid, arena and career integration PASS.
- `frontier_gameplay_smoke.gd`: six racers, bot navigation, progress and realtime performance PASS.
- Career, boss/replayability, pre-race, track, arena, game, survival and release regression tests PASS.
- Performance baseline remains mean 6.90 ms, p95 6.94 ms, approximately 145 FPS.
- Visual review at 1280×720 completed for both race and survival layouts.
- Follow-up arena review confirmed all six cover sprites, matching collision footprints and undistorted small props.

## Generated asset prompts

Built-in ImageGen was used for three project assets:

1. Seamless orthographic rust-frontier desert/industrial ground with ochre soil, gravel and subtle scrap.
2. Seamless orthographic charcoal frontier asphalt with cracks, patches and windblown sand.
3. Transparent 3×2 orthographic industrial-prop atlas with six isolated rusted structures/objects.
