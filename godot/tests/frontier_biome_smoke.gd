extends SceneTree

const TRACK_PATHS := [
	"res://resources/frontier_express.tres",
	"res://resources/copper_ravine.tres",
]
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FRONTIER FAIL: ", label)

func run() -> void:
	for path in TRACK_PATHS:
		var config := load(path) as TrackConfig
		check(config != null, "%s loads" % path)
		if config == null: continue
		check(config.biome_id == &"rust_frontier", "%s biome" % path)
		check(config.weather_type == &"dust_storm" and config.storm_strength >= 0.6, "%s storm" % path)
		check(config.hazard_profile == &"frontier" and config.hazard_count >= 7, "%s hazards" % path)
		check(config.bonus_hotspots.size() >= 5, "%s bonus lines" % path)
		var track := Track.new()
		track.config = config
		root.add_child(track)
		await process_frame
		check(track.total_length > 6000.0, "%s is a long circuit" % path)
		check(track.weather != null, "%s weather runtime" % path)
		check(track.get_tree().get_nodes_in_group("oil_spots").size() >= 1, "%s oil hazard" % path)
		for position in track.get_start_grid(6):
			check(track.is_point_on_track(position, 18.0), "%s grid on road" % path)
		var vehicle := Vehicle.new()
		vehicle.config = load("res://resources/vehicles/raider.tres")
		track.add_child(vehicle)
		vehicle.global_position = track.get_start_position()
		track.weather.force_storm(true)
		track.apply_surface_to(vehicle)
		check(vehicle._surface_traction_target < config.road_traction, "%s storm reduces grip" % path)
		track.free()
		await process_frame

	var arena_config := load("res://resources/oil_cauldron_arena.tres") as ArenaConfig
	check(arena_config != null and arena_config.biome_id == &"rust_frontier", "frontier arena config")
	var arena := Arena.new()
	arena.config = arena_config
	root.add_child(arena)
	await process_frame
	check(arena.weather != null, "arena storm runtime")
	check(arena.get_obstacles().size() >= 6, "arena cover layout")
	check(arena.get_spawn_points(6).size() == 6, "arena spawn layout")
	check(arena.get_node_or_null("ObstacleFootprint") != null, "arena obstacles have contrast footprints")
	for node in arena.get_children():
		if String(node.name).begins_with("ObstacleArt"):
			check(is_equal_approx(absf(node.scale.x), absf(node.scale.y)), "arena prop keeps original proportions")
	arena.free()

	for id in [&"frontier_express", &"oil_cauldron", &"copper_ravine"]:
		check(not CareerSession.event_by_id(id).is_empty(), "career event %s" % id)
	check(CareerSession.EVENTS.size() == 9, "career expanded to nine events")
	PlayerProfile.path_override = "res://.frontier_profile.cfg"
	CareerSession.select_event(&"oil_cauldron")
	PreRaceSetup.request_mode(&"survival")
	var pre_race: Node = (load("res://scenes/PreRace.tscn") as PackedScene).instantiate()
	root.add_child(pre_race)
	await process_frame
	check(pre_race.get_node("%ModeName").text.contains("НЕФТЯНОЙ КОТЁЛ"), "arena has pre-race briefing")
	pre_race.free()
	PlayerProfile.path_override = ""
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = "res://.frontier_profile.cfg" + suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("FRONTIER BIOME: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
