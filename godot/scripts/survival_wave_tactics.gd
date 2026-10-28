extends RefCounted
## Deterministic slot composition for ordinary Survival only. Empty profiles
## preserve skirmish/boss cycles and every Career arena contract.
const Driver = preload("res://scripts/arena_bot.gd")

static func profile(wave_id: StringName, index: int) -> Dictionary:
	var role: int = index % 3 + 1
	match wave_id:
		&"supply_rush":
			var collector := index % 2 == 0
			return {"strategy": Driver.Strategy.SCAVENGER if collector else (Driver.Strategy.HUNTER if index % 4 == 1 else Driver.Strategy.BRAWLER),
				"team_role": role, "supply_search_radius": 680.0 if collector else 220.0,
				"exclusive_supply_targets": true, "flank_width": 135.0}
		&"elite_team":
			return {"strategy": Driver.Strategy.BRAWLER if role == Driver.TeamRole.VANGUARD else Driver.Strategy.HUNTER,
				"team_role": role, "supply_search_radius": 520.0 if role == Driver.TeamRole.SUPPORT else 400.0,
				"exclusive_supply_targets": true, "flank_width": 180.0 if role == Driver.TeamRole.FLANKER else 135.0,
				"flank_approach_offset": 160.0 if role == Driver.TeamRole.FLANKER else 0.0}
		&"onslaught":
			return {"strategy": Driver.Strategy.BRAWLER if index % 3 == 0 else Driver.Strategy.HUNTER,
				"team_role": role, "supply_search_radius": 400.0,
				"exclusive_supply_targets": true, "flank_width": 135.0}
	return {}


static func apply_to(driver: ArenaBot, wave_id: StringName, index: int) -> void:
	var values := profile(wave_id, index)
	for key in values:
		driver.set(key, values[key])
