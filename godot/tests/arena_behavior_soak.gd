extends SceneTree
## Gameplay navigation across all biomes, including group traffic and combat.

var failures := 0
var scenery_deaths := 0
var traces: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for entry in SurvivalRunData.ARENAS:
		var selected := Array(OS.get_cmdline_user_args()).filter(func(arg): return arg.begins_with("--arena="))
		if not selected.is_empty() and String(entry.id) != selected[0].trim_prefix("--arena="): continue
		SurvivalRunData.selected_arena_id = entry.id
		var game := (load("res://scenes/ArenaBattle.tscn") as PackedScene).instantiate() as Survival
		root.add_child(game)
		await process_frame
		var durable := game.player.config.duplicate() as VehicleConfig
		durable.max_health = 50000.0
		durable.engine_health = 50000.0
		durable.wheels_health = 50000.0
		durable.damage_resistance = 0.75
		game.player.reconfigure(durable)
		game.player.freeze = true
		await sample(game, String(entry.id), "cars", 1500)
		game._clear_bullets()
		game._clear_enemies()
		await process_frame
		game._referee_spawned = false
		game.start_round(5)
		game._clear_enemies()
		game._spawn_referee()
		game._spawn_biker_squad()
		await sample(game, String(entry.id), "bikes", 1800)
		game.free()
		await process_frame
	FileAccess.open("/tmp/metal-road-arena-behavior.json", FileAccess.WRITE).store_string(JSON.stringify(traces))
	print("ARENA BEHAVIOR SOAK: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)

func sample(game: Survival, biome: String, kind: String, frames: int) -> void:
	scenery_deaths = 0
	var actors: Array[Vehicle] = []
	var paths: Array = []
	var best_distance := INF
	var total_travel := 0.0
	var previous: Array[Vector2] = []
	for enemy in game._enemies:
		if kind == "bikes" and not bool(enemy.get_meta("biker", false)): continue
		actors.append(enemy)
		paths.append([])
		previous.append(enemy.global_position)
		enemy.died.connect(func(v: Vehicle) -> void:
			if is_instance_valid(v.last_attacker) and v.last_attacker is StaticBody2D:
				scenery_deaths += 1
				print("SCENERY CRASH ", biome, " ", kind, " at=", v.position, " obstacle=", v.last_attacker.name, " velocity=", v.get_last_velocity()))
	for frame in frames:
		await physics_frame
		for index in actors.size():
			var actor := actors[index]
			if not is_instance_valid(actor) or not actor.alive: continue
			best_distance = minf(best_distance, actor.global_position.distance_to(game.player.global_position))
			total_travel += previous[index].distance_to(actor.global_position)
			previous[index] = actor.global_position
			if frame % 12 == 0:
				paths[index].append([actor.position.x, actor.position.y, actor.rotation, actor.get_speed(), actor.steer])
	var survivors := actors.filter(func(v): return is_instance_valid(v) and v.alive).size()
	print("BEHAVIOR ", biome, " ", kind, " alive=", survivors, "/", actors.size(), " scenery_deaths=", scenery_deaths, " closest=", snappedf(best_distance, 1), " travel=", snappedf(total_travel, 1))
	if scenery_deaths > 1 or best_distance > 260.0 or total_travel < float(actors.size()) * 280.0:
		failures += 1
	var obstacles: Array = []
	for rect in game.arena.get_obstacles():
		obstacles.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	traces.append({"biome": biome, "kind": kind, "paths": paths, "obstacles": obstacles,
		"target": [game.player.position.x, game.player.position.y]})
