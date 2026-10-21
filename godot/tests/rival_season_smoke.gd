extends SceneTree

var failures := 0
var profile_path := "res://.rival_season_profile_test.cfg"
var loadout_path := "res://.rival_season_loadout_test.cfg"

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("RIVAL SEASON FAIL: ", label)

func run() -> void:
	PlayerProfile.path_override = profile_path
	LoadoutProfile.path_override = loadout_path
	PlayerProfile.save({"credits":0, "vehicles":[&"raider"], "weapons":[&"machine_gun"], "vehicle_states":{}, "career":{"driver_id":&"flint"}})
	LoadoutProfile.save_ids(&"raider", &"machine_gun")
	var state := PlayerProfile.career_state()
	check(state.rival_levels.size() == 5, "five persistent rivals are migrated into profile")
	check(CareerSession.EVENTS.size() >= 6 and CareerSession.EVENTS[5].id == &"zero_finale", "season finale exists")

	CareerSession.select_event(&"iron_open")
	var result := CareerSession.record_result({"status":&"FINISHED", "position":2, "rival_positions":{"razor":1,"bolt":3,"nyx":4,"grit":5,"zero":6}})
	state = PlayerProfile.career_state()
	check(int(state.season_points.player) == 7 and int(state.season_points.razor) == 10, "season table records player and rival points")
	check(int(state.rival_levels.razor) == 2, "rivals upgrade between completed stages")
	check(not state.last_rival_news.is_empty(), "workshop upgrade news is generated")
	check(state.personal_rival_id != &"", "personal rival is selected from close finishes")
	check(not String(result.personal_rival).is_empty(), "result reports personal rival")
	var game := (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for bot in game._bots: bot.set_physics_process(false)
	check(game._bots.size() == 5, "career race uses full persistent rival roster")
	for index in game._bots.size():
		var rival: Dictionary = RivalRoster.at(index)
		var car := game._bots[index].get_parent() as Vehicle
		check(car.get_meta("rival_id", &"") == rival.id, "race slot %d keeps rival identity" % index)
		check(car.config.vehicle_id == rival.vehicle, "race slot %d uses rival signature vehicle" % index)
	game.free()
	await process_frame

	var hq := (load("res://scenes/RivalHQ.tscn") as PackedScene).instantiate() as RivalHQ
	root.add_child(hq)
	await process_frame
	check(hq.get_node("%RivalList").get_child_count() == 5, "rival headquarters lists full roster")
	check(hq.get_node("%Portrait").texture != null, "rival dossier loads portrait")
	hq.free()
	await process_frame

	var lineup := (load("res://scenes/RivalLineup.tscn") as PackedScene).instantiate() as RivalLineup
	root.add_child(lineup)
	await process_frame
	check(lineup.get_node("%Grid").get_child_count() == 6, "pre-race lineup contains player and five rivals")
	lineup.free()
	await process_frame

	CareerSession.select_event(&"zero_finale")
	var final_result := CareerSession.record_result({"status":&"FINISHED", "position":1})
	check(bool(final_result.season_champion), "winning final grants season champion status")
	check(&"behemoth" in PlayerProfile.read().vehicles, "final unlocks the unique prize vehicle")

	CareerSession.clear_selection()
	PlayerProfile.path_override = ""
	LoadoutProfile.path_override = ""
	for path in [profile_path, loadout_path]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	print("RIVAL SEASON: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
