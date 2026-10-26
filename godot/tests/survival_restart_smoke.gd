extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("RESTART FAIL: ",label)
func count_props(game: Survival) -> int:
	return game.arena.get_tree().get_nodes_in_group("arena_obstacles").filter(func(n): return game.arena.is_ancestor_of(n) and not n.destroyed).size()
func count_barrels(game: Survival) -> int:
	return get_nodes_in_group("destructibles").filter(func(n): return n is ExplosiveBarrel and game.arena.is_ancestor_of(n) and not n.destroyed).size()
func settle() -> void:
	await process_frame
	await physics_frame
	await process_frame
func restart(game: Survival) -> void:
	game._on_retry_requested()
	await settle()
func run() -> void:
	PlayerProfile.path_override="res://restart_test_profile.cfg"
	LoadoutProfile.path_override="res://restart_test_loadout.cfg"
	var game := load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	await settle()
	var initial_props := count_props(game)
	var initial_barrels := count_barrels(game)
	var crate := get_nodes_in_group("arena_obstacles").filter(func(n): return n.kind==&"crate")[0] as MapProp
	crate.take_damage(1000)
	check(count_props(game)==initial_props-1,"crate destroyed")
	game.start_round(2)
	check(count_props(game)==initial_props-1,"wave transition preserves destruction")
	await restart(game)
	check(count_props(game)==initial_props,"restart restores crate")
	var barrel := get_nodes_in_group("destructibles").filter(func(n): return n is ExplosiveBarrel)[0] as ExplosiveBarrel
	barrel.explode()
	await restart(game)
	check(count_barrels(game)==initial_barrels,"restart restores barrels")
	check(get_nodes_in_group("spike_strips").size()==1,"exactly one spike strip")
	game.arena_hazards._warning=true
	game.arena_hazards._active_time=1.4
	game.arena_hazards._clock=0.01
	game.player.activate_temporary_weapon(load("res://resources/weapons/shotgun.tres"),25)
	game.player.activate_boost(8)
	game.player.activate_ram_boost(9)
	game.player.set_surface_modifier(0.38,0.72,game.arena)
	var bullet := load("res://scenes/Bullet.tscn").instantiate() as Bullet
	game.bullets.add_child(bullet)
	bullet.setup(Vector2(500,600),Vector2.RIGHT,load("res://resources/weapons/machine_gun.tres"),game.player)
	game.get_node("CombatVFX").spawn_explosion(Vector2.ZERO)
	await restart(game)
	check(not game.arena_hazards._warning and game.arena_hazards._active_time==0 and game.arena_hazards._clock>5,"hazard state restored")
	check(not game.player.has_temporary_weapon() and not game.player.is_boost_active() and not game.player.is_ram_boost_active(),"temporary effects reset")
	check(game.player._surface_modifiers.size()<=2 and game.player.get_surface_traction_factor()==1,"old surface modifiers cleared")
	check(game.bullets.get_child_count()==0 and game.get_node("CombatVFX").events.is_empty(),"old bullet/VFX cleared")
	var old_enemy := game._enemies[0]
	old_enemy.take_damage(100000,&"body",game.player)
	game._on_retry_requested()
	await settle()
	check(game._active_crew_count()==0 and game._score==0 and game._kills==0,"same-frame death restart rejects stale crew and scores")
	game._end_round(false)
	await settle()
	var final_result := game._run_result(&"DEFEAT")
	var final_message: String = game.hud._message.text
	var final_nodes := game.get_child_count()
	await create_timer(3).timeout
	check(game._run_result(&"DEFEAT")==final_result,"results stay immutable")
	check(game.bonus_spawner._pending_pickups.is_empty() and game.get_child_count()==final_nodes,"results create no new gameplay")
	check(game.hud._message.text==final_message and game.results.visible,"results UI remains visible")
	game.results.get_node("%RetryButton").pressed.emit()
	await settle()
	check(not game.results.visible and not game._session_finished and game.player.alive,"Retry resumes gameplay")
	var baseline := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var baseline_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var last_count := baseline
	for index in 100:
		await restart(game)
		check(game._alive_enemies()==2 and game._pending_enemies.size()==1 and count_props(game)==initial_props and count_barrels(game)==initial_barrels,"restart counts "+str(index))
		last_count=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		check(last_count<=baseline+2,"bounded nodes "+str(index))
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==baseline_orphans,"no orphan accumulation")
	print("RESTART 100 nodes baseline=",baseline," final=",last_count," orphans=",baseline_orphans)
	game.queue_free()
	await settle()
	await create_timer(0.5).timeout
	print("SURVIVAL RESTART: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
