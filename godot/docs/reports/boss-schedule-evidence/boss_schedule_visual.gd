extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func freeze_cars(game: Survival) -> void:
	game.player.freeze=true
	for enemy in game._enemies:
		enemy.freeze=true
		enemy.get_node("ArenaBot").set_physics_process(false)
		enemy.gun.set_physics_process(false)
func kill(game: Survival) -> void:
	for enemy in game._enemies.duplicate():
		if enemy.alive: enemy.take_damage(100000,&"body",game.player)
func shot(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://"+file)
func run() -> void:
	PlayerProfile.path_override="res://visual_schedule_profile.cfg"
	LoadoutProfile.path_override="res://visual_schedule_loadout.cfg"
	CareerSession.clear_selection()
	change_scene_to_file("res://scenes/ArenaBattle.tscn")
	await scene_changed
	var game:=current_scene as Survival
	freeze_cars(game)
	kill(game)
	await shot("boss-schedule-wave1-complete.png")
	game._offer_upgrade()
	await shot("boss-schedule-draft.png")
	game._on_perk_selected(SurvivalRunData.perk_choices(1,[])[0])
	game.start_round(5)
	freeze_cars(game)
	kill(game)
	await process_frame
	freeze_cars(game)
	game._process(0)
	await shot("boss-schedule-wave5.png")
	print("BOSS SCHEDULE GUI: COMPLETE")
	quit()
