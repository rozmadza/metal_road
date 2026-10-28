extends SceneTree
const Cache = preload("res://scripts/bonus_weapon_cache.gd")
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("BONUS WEAPON CACHE FAIL: ", label)


func run() -> void:
	check(Cache.PATHS.size() == 7, "exactly seven standard paths")
	var direct_spawner := BonusSpawner.new()
	root.add_child(direct_spawner)
	check(Cache.is_ready(), "direct scene setup prepares before gameplay tick")
	direct_spawner.queue_free()
	await process_frame
	check(Cache.prepare(), "preparation succeeds")
	check(Cache.is_ready(), "cache ready")
	var resource_ids: Array[int] = []
	var texture_ids: Array[int] = []
	for path in Cache.PATHS:
		var config := Cache.get_config(path)
		check(config != null and config.texture != null, "config and texture: %s" % path)
		if config == null or config.texture == null:
			continue
		resource_ids.append(config.get_instance_id())
		texture_ids.append(config.texture.get_instance_id())
		check(ResourceLoader.has_cached(path), "Godot resource cached: %s" % path)
		check(config == load(path), "same shared config: %s" % path)
	check(resource_ids.size() == 7 and texture_ids.size() == 7, "all seven resolved")
	check(Cache.prepare(), "repeat preparation idempotent")
	for index in Cache.PATHS.size():
		check(Cache.get_config(Cache.PATHS[index]).get_instance_id() == resource_ids[index],
			"repeat preparation keeps strong reference %d" % index)
	var shared := Cache.get_config(Cache.PATHS[0])
	var gun_a := MachineGun.new()
	var gun_b := MachineGun.new()
	gun_a.equip(shared)
	gun_b.equip(shared)
	gun_a.ammo -= 1
	check(gun_b.ammo == shared.magazine_size and shared.magazine_size == 18,
		"per-vehicle ammo remains independent of shared config")
	gun_a.free()
	gun_b.free()

	var track := (load("res://scenes/Track.tscn") as PackedScene).instantiate() as Track
	root.add_child(track)
	var spawner := BonusSpawner.new()
	spawner.setup_for_track(track)
	root.add_child(spawner)
	var collector := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
	root.add_child(collector)
	check(Cache.PATHS == spawner.weapon_paths, "path order unchanged")
	for path in Cache.PATHS:
		spawner.reset()
		await process_frame
		spawner.weapon_paths = [path]
		var pickup := spawner.spawn_random_bonus(BonusPickup.Kind.WEAPON)
		check(pickup != null, "Race pickup created: %s" % path)
		if pickup != null:
			check(pickup.weapon_config == Cache.get_config(path), "pickup shares config: %s" % path)
			check(pickup.weapon_config.texture == Cache.get_config(path).texture, "pickup shares texture: %s" % path)
			check(pickup.collect(collector), "Race collects weapon: %s" % path)
			check(collector.gun.config == Cache.get_config(path), "Race equips cached weapon: %s" % path)
			collector.reset_to(Vector2.ZERO, 0.0)
	spawner.reset()
	await process_frame

	var game := (load("res://scenes/ArenaBattle.tscn") as PackedScene).instantiate() as Survival
	root.add_child(game)
	var arena_spawner := game.bonus_spawner
	check(arena_spawner.weapon_paths == Cache.PATHS, "Survival uses same seven paths")
	check(arena_spawner.batch_size == 3 and arena_spawner.minimum_weapons_per_batch == 2,
		"Survival batch unchanged")
	arena_spawner._announce_next_pickup()
	check(arena_spawner._pending_pickups.size() == 3, "Survival batch created")
	for pickup in arena_spawner._pending_pickups:
		if pickup.kind == BonusPickup.Kind.WEAPON:
			check(pickup.weapon_config in Cache._configs.values(), "Survival weapon from cache")
	game._on_retry_requested()
	await process_frame
	await physics_frame
	await process_frame
	for path in Cache.PATHS:
		check(Cache.get_config(path) != null and ResourceLoader.has_cached(path),
			"strong reference survives Restart: %s" % path)
	game.queue_free()
	collector.queue_free()
	spawner.queue_free()
	track.queue_free()
	await process_frame
	await process_frame
	print("BONUS WEAPON CACHE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
