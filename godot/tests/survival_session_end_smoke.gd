extends SceneTree
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures+=1
		printerr("SESSION END FAIL: ",label)
func run() -> void:
	PlayerProfile.path_override="res://session_end_profile.cfg"
	var game := load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	await physics_frame
	game._spawn_crew_from_vehicle(game._enemies[0])
	var old_generation := game._round_generation
	game._end_round(false)
	await process_frame
	var snapshot := game._run_result(&"DEFEAT")
	var objects := game.get_child_count()
	for frame in 1800: await physics_frame
	check(game._run_result(&"DEFEAT")==snapshot,"30 seconds preserve results")
	check(game.get_child_count()==objects,"30 seconds spawn no objects")
	check(not game.bonus_spawner.can_process() and not game.arena_hazards.can_process(),"bonus and hazards stopped")
	for crew in get_nodes_in_group("escaping_crew"):
		check(not crew.can_process(),"crew stopped")
	check(game.player.freeze and game.results.can_process(),"world frozen, results interactive")
	game._on_retry_requested()
	await process_frame
	game._spawn_crew_deferred(Vector2(500,600),0,Vector2(40,24),old_generation)
	game._spawn_referee_deferred(old_generation)
	check(game._active_crew_count()==0 and not is_instance_valid(game._boss),"old generation rejected")
	game.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("SURVIVAL SESSION END: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
