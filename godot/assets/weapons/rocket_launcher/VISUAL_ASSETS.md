# Rocket Launcher — Variant A integration contract

` Variant A.png` is the owner's concept sheet, not a game atlas. Do not load it
as a projectile or remove its background algorithmically as a substitute for
finished art. The existing `rocket_launcher_roof.png` remains the roof/HUD icon.
The four prepared game PNGs are now present and assigned (v2). Their untouched
owner-provided source files retain their original Russian names. Preparation
records, source hashes and actual Godot comparisons are in
`docs/reports/rocket-launcher-v2-evidence/`.

Assign finished textures in `resources/weapon_visuals/rocket_launcher.tres` using
Godot's Inspector. `WeaponConfig.visual_profile` already references that resource.
All dimensions below are **per frame**. Atlas order: left to right, then next row.

| Prepared game file | Texture/atlas size, px | World canvas | Pivot in frame | Consumer |
| --- | --- | --- | --- | --- |
| `projectile_body.png` | 96×64, one frame | 24×16 | (32,32), collision origin; +X nose | Bullet via profile |
| `exhaust_strip.png` | 64×32, one frame | 22×12 | (64,16), hot end on right; extends left from Bullet (-6,0) | Bullet via profile |
| `muzzle_sheet.png` | 288×128: 3×2 of 96×64, 6 frames | 26×18 | (16,32), muzzle point; +X | MachineGun via profile |
| `explosion_sheet.png` | 1024×512: 4×2 of 256×256, 8 frames | 210×210 at radius105 | (128,128) | CombatVFX via profile |

Use PNG RGBA8, transparent background, straight alpha, sRGB. Preserve frame pivots
and four pixels of transparent padding inside each cell to avoid atlas bleeding.
No text, borders, baked checkerboards or separate contact shadow plane. Metal,
orange fire, grey smoke, small sparks/debris should follow the approved concept.
Keep the hit-origin near the front third of the rocket, not at its nose tip.

The muzzle uses the existing 0.11s flash timer. The explosion uses the existing
0.48s VFX TTL. Animation reaches the last frame before expiry and never loops.
The exhaust can optionally become a row-major multi-frame atlas: set grid,
frames and fps; its existing world size/offset stays short. The body/exhaust pair
activates together only when both textures validate. Muzzle and explosion can
activate independently; missing/invalid clips retain their original drawing.

Import losslessly, `fix_alpha_border=true`, `premult_alpha=false`; initially no
mipmaps, use the project's existing filtering. All consumers share the resource:
no per-shot texture loads, duplicated images, added physics shapes or particles.

Only CombatVFX renders an enabled asset explosion. The Bullet root still lives
through its original ~0.18s tween for active-projectile accounting; it draws no
second blast and its scale tween cannot enlarge the atlas. If CombatVFX is absent,
the Bullet keeps the original procedural flash. Existing budget48/priority/TTL
remain authoritative; per-target damage feedback is deliberately preserved.

After any future art replacement, rerun `tests/rocket_visual_profile_smoke.gd`, graphical
captures at 1280×720 and 800×600, and the release regression suite. All four components are active and graphical/performance checks have been run;
see the v2 report for measured results and remaining manual art acceptance.
The supplied atlas poses were real distinct stages; preparation aligns muzzle
origins, removes the illustrated metal nozzle, repacks frames and fades the last
smoke frames. Source explosion borders already touch in places: a four-pixel
edge fade avoids seams but cannot reconstruct missing source detail.
