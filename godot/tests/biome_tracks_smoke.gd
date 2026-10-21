extends SceneTree
## Verifies the career track set has distinct art, handling and risk/reward rules.

const TRACKS := [
	"res://resources/iron_circuit.tres",
	"res://resources/dust_spiral.tres",
	"res://resources/broken_crown.tres",
	"res://resources/ashen_crown.tres",
]

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("BIOME TRACKS FAIL: ", label)


func run() -> void:
	var biome_ids: Dictionary = {}
	var surface_paths: Dictionary = {}
	for path in TRACKS:
		var config := load(path) as TrackConfig
		check(config != null, "%s loads" % path)
		if config == null:
			continue
		biome_ids[config.biome_id] = true
		surface_paths[config.surface_texture.resource_path] = true
		check(config.background_texture != null, "%s has biome ground" % path)
		check(config.surface_texture.resource_path.contains("/biomes/"), "%s uses biome road art" % path)
		check(not config.biome_description.is_empty(), "%s explains driving conditions" % path)
		check(config.bonus_hotspots.size() >= 3, "%s has risk/reward bonus lines" % path)
		check(config.hazard_count >= 3, "%s has track hazards" % path)

		var track := Track.new()
		track.config = config
		root.add_child(track)
		await process_frame
		check(track.path_points.size() > config.centerline.size() * 4, "%s has rounded geometry" % path)
		for position in track.get_start_grid(6):
			check(track.is_point_on_track(position, 18.0), "%s start grid stays on road" % path)
		var vehicle := Vehicle.new()
		vehicle.global_position = track.get_start_position()
		track.add_child(vehicle)
		track.apply_surface_to(vehicle)
		check(is_equal_approx(vehicle._surface_traction_target, config.road_traction), "%s applies road grip" % path)
		vehicle.global_position = track.get_bounds().end + Vector2(500.0, 500.0)
		track.apply_surface_to(vehicle)
		check(is_equal_approx(vehicle._surface_traction_target, config.offroad_traction), "%s applies off-road grip" % path)
		track.free()
		await process_frame

	check(biome_ids.size() == 3, "career contains industrial, desert and ruined-city biomes")
	check(surface_paths.size() == 3, "each biome has a distinct road material")
	var preview := TrackPreview.new()
	preview.custom_minimum_size = Vector2(160, 72)
	root.add_child(preview)
	preview.set_track(load(TRACKS[1]) as TrackConfig)
	await process_frame
	check(preview.config.biome_id == &"desert", "pre-race map accepts selected biome")
	preview.free()

	print("BIOME TRACKS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
