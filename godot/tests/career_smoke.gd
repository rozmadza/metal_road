extends SceneTree

var failures := 0
var profile_path := "res://.career_profile_test.cfg"
var loadout_path := "res://.career_loadout_test.cfg"


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("CAREER FAIL: ", label)


func run() -> void:
	PlayerProfile.path_override = profile_path
	LoadoutProfile.path_override = loadout_path
	PlayerProfile.save({
		"credits": 1000,
		"vehicles": [&"raider"],
		"weapons": [&"machine_gun"],
		"vehicle_states": {},
		"weapon_upgrades": [],
	})
	LoadoutProfile.save_ids(&"raider", &"machine_gun")
	var career := (load("res://scenes/Career.tscn") as PackedScene).instantiate() as CareerScreen
	root.add_child(career)
	await process_frame
	check(career.get_node("%EventList").get_child_count() == CareerSession.EVENTS.size(), "all season events are shown")
	check(not career.get_node("%StartButton").disabled, "first event is unlocked")
	career.get_node("%EventList").get_child(1).pressed.emit()
	check(career.get_node("%StartButton").disabled, "second event starts locked")
	career.free()
	await process_frame

	CareerSession.select_event(&"iron_open")
	var summary := CareerSession.record_result({"status": &"FINISHED", "position": 2, "kills": 0, "pickups": 0})
	var profile := PlayerProfile.read()
	check(&"iron_open" in profile.career.completed_events, "completed event is saved")
	check(&"nomad" in profile.vehicles, "prize vehicle is unlocked")
	check(int(summary.career_bonus) == 850, "event and objective rewards are granted once")
	check(CareerSession.event_unlocked(1, profile.career), "completion unlocks next event")
	var credits_after := int(profile.credits)
	CareerSession.record_result({"status": &"FINISHED", "position": 1, "kills": 0, "pickups": 0})
	check(int(PlayerProfile.read().credits) == credits_after, "career reward cannot be farmed twice")

	CareerSession.start_or_resume_championship()
	for event in CareerSession.EVENTS.slice(0, CareerSession.CHAMPIONSHIP_EVENT_COUNT):
		CareerSession.select_event(event.id, true)
		CareerSession.record_result({"status": &"FINISHED", "position": 1, "kills": 1, "pickups": 3, "event_won": true})
	var state := PlayerProfile.career_state()
	check(bool(state.championship_complete), "three events complete the championship")
	check(int(state.championship_points.get("ВЫ", 0)) == 30, "championship points accumulate")
	check(CareerSession.event_unlocked(3, state), "completed race series unlocks arena contract")

	CareerSession.clear_selection()
	PlayerProfile.path_override = ""
	LoadoutProfile.path_override = ""
	for path in [profile_path, loadout_path]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)
	print("CAREER: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

