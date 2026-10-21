# Sprint B–C–D audit

Phase B: HUD scenes use fixed 476×140 panels. Game/Survival already pass their
actual Vehicle to HUD every frame. Reuse both coordinator APIs and ModuleStatus;
share a compact VehicleReadout and a Vehicle.get_hud_state data contract. Keep
root Info node for existing assets smoke. Debug occupies a separate right inset.
Baseline from preceding user playtest: 17/17 PASS; code unchanged since it.

Phase C: reuse combatants/Bullet/Vehicle.damage/death. Race flag enables combat;
destruction means DNF, no automatic respawn. Attribute actual damage and kills
through Vehicle signals, keeping take_damage(amount, module) backwards compatible.
Do not change noncombat Vehicle behavior. Common effects/audio work in both modes.

Phase D: reuse Track projection, length and finish segment; keep race runtime in
small RaceProgress class, parameters in TrackConfig. Validate sequential progress,
forward finish intersection, and no finish oscillation exploit. Results are a
separate Control scene; gameplay stops on player FINISHED/DNF. Credits remain 0
until the explicitly later economy phase, no fabricated currency reward.

No Garage expansion, economy, environment expansion or audio overhaul this sprint.
