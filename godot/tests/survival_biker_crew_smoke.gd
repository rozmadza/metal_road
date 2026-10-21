extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var game := (load("res://scenes/ArenaBattle.tscn") as PackedScene).instantiate() as Survival
	root.add_child(game)
	await process_frame
	game._clear_enemies()
	await process_frame

	game._referee_spawned = false
	game._spawn_referee()
	check(is_instance_valid(game._boss) and game._boss.alive, "Referee spawns for reinforcement test")
	var spawned := game._spawn_biker_squad()
	check(spawned == 6, "Referee deploys exactly six bikers")
	check(game._alive_biker_count() == 6, "all six bikers enter combat")
	var biker: Vehicle
	for enemy in game._enemies:
		if bool(enemy.get_meta("biker", false)):
			biker = enemy
			break
	check(biker != null, "biker vehicle exists")
	if biker != null:
		check(biker.config.vehicle_id == &"referee_biker", "biker uses exclusive vehicle")
		check(biker.config.max_speed >= 170.0 and biker.config.max_health <= 60.0, "biker is fast and fragile")
		check(biker.config.length <= game.player.config.length * 0.65, "motorcycle scale is proportional to a car")
		check(biker.has_temporary_weapon() and biker.gun.config.weapon_id == &"biker_pistol", "biker starts with pistols")
		var controller := biker.get_node_or_null("ArenaBot") as ArenaBot
		check(controller != null and controller.focus_player, "biker hunts the player")
		check(StringName(biker.get_meta("squad_id", &"")) == &"referee", "biker belongs to the Referee squad")
		check(biker._same_combat_squad(game._boss), "Referee formation contact cannot destroy its own bikers")
		biker._last_velocity = Vector2(60.0, 0.0)
		biker._on_body_entered(game._boss)
		check(biker.alive, "friendly formation contact does not count as a fatal crash")
		var scenery := StaticBody2D.new()
		biker._on_body_entered(scenery)
		scenery.free()
		check(not biker.alive, "one real crash destroys a biker")
	game._biker_deploy_timer = 0.01
	game._update_boss(0.2)
	check(game._biker_deploy_timer > 0.0, "new biker squad waits while current riders remain")

	var wreck := game.bot_scene.instantiate() as Vehicle
	wreck.config = LoadoutProfile.vehicle_config(&"raider")
	game.add_child(wreck)
	wreck.global_position = game.arena.get_bounds().get_center() + Vector2(180, 0)
	var crew_before := game.get_tree().get_nodes_in_group("escaping_crew").size()
	check(game._spawn_crew_from_vehicle(wreck) == 2, "destroyed normal car releases pilot and assistant")
	var crew_nodes := game.get_tree().get_nodes_in_group("escaping_crew")
	check(crew_nodes.size() == crew_before + 2, "two fleeing crew targets are active")
	var pilot := crew_nodes[crew_nodes.size() - 2] as EscapingCrew
	var mechanic := crew_nodes[crew_nodes.size() - 1] as EscapingCrew
	check(pilot.role != mechanic.role, "crew contains two different roles")
	check(pilot.escape_direction.dot(mechanic.escape_direction) < 0.4, "crew runs in different directions")
	check(pilot.run_speed <= 60.0 and mechanic.run_speed <= 55.0, "crew runs much slower than arena vehicles")
	var pilot_frame := pilot._sprite.frame
	pilot._physics_process(0.2)
	check(pilot._sprite.frame != pilot_frame, "running crew animates arms and legs")
	check(game._spawn_crew_from_vehicle(wreck) == 0, "same wreck cannot release crew twice")
	check(game._spawn_crew_from_vehicle(game._boss) == 0, "boss never releases fleeing crew")

	pilot._age = 1.0
	game.player.linear_velocity = Vector2(90, 0)
	var score_before := game._score
	check(pilot.crush(game.player), "player can run over fleeing crew")
	check(game._score >= score_before + Survival.CREW_CRUSH_SCORE, "run-over grants bonus score")
	check(game._crew_crushed == 1, "run-over counter increments")
	check(not game.get_tree().get_nodes_in_group("crew_remains").is_empty(), "run-over leaves corpse and stain")

	game.free()
	await process_frame
	print("SURVIVAL BIKER CREW: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(ok: bool, label: String) -> void:
	if ok:
		print("SURVIVAL BIKER CREW ok: ", label)
	else:
		failures += 1
		printerr("SURVIVAL BIKER CREW FAIL: ", label)
