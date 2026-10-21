extends SceneTree

var failures := 0
var profile_path := "res://.boss_replay_profile_test.cfg"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("BOSS/REPLAY FAIL: ", label)

func run() -> void:
	PlayerProfile.path_override = profile_path
	PlayerProfile.save({"credits": 0, "vehicles": [&"raider"], "weapons": [&"machine_gun"], "vehicle_states": {}, "career": {}})
	check(CareerSession.EVENTS.size() == 9, "nine authored career events")
	var daily_a := CareerSession.daily_event("2026-10-17")
	var daily_b := CareerSession.daily_event("2026-10-17")
	check(daily_a == daily_b and bool(daily_a.repeatable), "daily challenge is deterministic")
	CareerSession.select_daily_challenge("2026-10-17")
	var daily_result := CareerSession.record_result({"status": &"FINISHED", "position": 1, "time": 88.0})
	var first_credits := int(PlayerProfile.read().credits)
	CareerSession.record_result({"status": &"FINISHED", "position": 1, "time": 92.0})
	check(int(daily_result.career_bonus) == int(daily_a.reward) and int(PlayerProfile.read().credits) == first_credits, "daily reward is claimed once")
	check(is_equal_approx(float(PlayerProfile.career_state().daily_best.get("2026-10-17", 0.0)), 88.0), "daily best time persists")
	CareerSession.select_event(&"grit_boss")
	var summary := CareerSession.record_result({"status": &"FINISHED", "position": 1, "repairs_used": 0, "rival_positions": {"grit": 2}})
	var state := PlayerProfile.career_state()
	check(bool(summary.success) and &"grit" in state.bosses_defeated, "boss victory persists")
	check(int(state.event_medals.get("grit_boss", 0)) == 3, "boss mastery awards three medals")
	CareerSession.select_event(&"grit_boss")
	var game := (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	await process_frame
	check(game.participants.size() == 2 and game.boss_vehicle != null, "boss duel trims roster to one boss")
	check(game.boss_vehicle.config.max_health > 100.0 and game.boss_vehicle.gun.enabled, "boss has reinforced health and weapon")
	game.boss_vehicle.health = game.boss_vehicle.config.max_health * 0.3
	game._update_boss_phase()
	check(game._boss_phase == 3 and game.hud.get_node("BossPanel").visible, "boss reaches phase three with HUD")
	game.free()
	CareerSession.clear_selection()
	PlayerProfile.path_override = ""
	var absolute := ProjectSettings.globalize_path(profile_path)
	if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	print("BOSS/REPLAYABILITY: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
