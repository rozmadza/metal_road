# Phase C report
Race registers player/bots in combatants, controlled by TrackConfig.combat_enabled.
Shared Vehicle/Bullet damage handles all participants; body hits report actual
removed HP and attacker. Death records DNF and a kill, blocks controls/weapons,
removes combat membership and defers physics shutdown. Only explicit Retry resets.
Existing ram algorithm reused; combat wall hits also damage the vehicle.
Common one-shot destruction VFX and a configurable original synthesized explosion
sound used by Race and Survival. No separate Race combat engine.
19/19 smoke PASS after fixing fixture setup timing (phase-c-logs/).
Real projectile player→bot, bot→player, bot→bot, shooter immunity, physical ram,
DNF, kill attribution, dead input, retry, noncombat flag checked in new smoke.
Windowed keyboard play: C-wall-damage (Body70/Engine77/Wheels78), C-combat and
C-destruction (Body7 + smoke/fire). Death/input contract also checked by smoke.
Next: D, real lap tracking, ranking, final results and navigation.
