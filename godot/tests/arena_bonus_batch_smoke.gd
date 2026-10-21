extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var game := load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	await process_frame
	var spawner := game.bonus_spawner
	check(spawner.batch_size == 3, "survival schedules three simultaneous crates")
	check(spawner.minimum_weapons_per_batch == 2, "each standard delivery guarantees two weapons")
	check(spawner.spawn_interval <= 5.0 and spawner.first_spawn_delay <= 2.8, "deliveries arrive faster")
	check(spawner.max_active >= 6, "two delivery batches may coexist")
	spawner.reset()
	spawner._announce_next_pickup()
	check(spawner._pending_pickups.size() == 3, "the complete batch is announced together")
	var positions: Array[Vector2] = []
	for pickup in spawner._pending_pickups:
		positions.append(pickup.global_position)
	var separated := true
	for left in positions.size():
		for right in range(left + 1, positions.size()):
			separated = separated and positions[left].distance_to(positions[right]) >= spawner.minimum_spawn_separation - 0.1
	check(separated, "batch crates use different arena locations")
	spawner._arm_announced_pickup()
	var weapon_count := 0
	for pickup in spawner._active_pickups:
		if pickup.kind == BonusPickup.Kind.WEAPON: weapon_count += 1
	check(spawner._active_pickups.size() == 3, "all crates become active on the same tick")
	check(weapon_count >= 2, "the active batch contains enough weapons for player and bots")
	game.free()
	await process_frame
	for entry in SurvivalRunData.ARENAS:
		var test_arena := Arena.new()
		test_arena.config = load(String(entry.path)) as ArenaConfig
		root.add_child(test_arena)
		await process_frame
		var director := BonusSpawner.new()
		director.batch_size = 3
		director.minimum_weapons_per_batch = 2
		director.minimum_spawn_separation = 210.0
		director.max_active = 6
		director.setup_for_arena(test_arena)
		root.add_child(director)
		director._announce_next_pickup()
		var location_positions: Array[Vector2] = []
		for pickup in director._pending_pickups:
			location_positions.append(pickup.global_position)
		var valid_layout := location_positions.size() == 3
		for left in location_positions.size():
			for right in range(left + 1, location_positions.size()):
				valid_layout = valid_layout and location_positions[left].distance_to(location_positions[right]) >= 209.9
		check(valid_layout, "%s supports a separated three-crate batch" % entry.name)
		director.free()
		test_arena.free()
	print("ARENA BONUS BATCH: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("ARENA BONUS BATCH FAIL: ", label)
