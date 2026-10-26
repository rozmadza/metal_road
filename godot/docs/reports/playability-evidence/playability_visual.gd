extends SceneTree
var game: Survival
func _initialize() -> void:
	run.call_deferred()
func shot(file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://"+file+".png")
func run() -> void:
	PlayerProfile.path_override="res://visual_playability_profile.cfg"
	LoadoutProfile.path_override="res://visual_playability_loadout.cfg"
	CareerSession.clear_selection()
	InputBindings.ensure_controller_defaults()
	change_scene_to_file("res://scenes/ArenaBattle.tscn")
	await scene_changed
	game=current_scene as Survival
	game.player.reset_to(Vector2(500,650),0)
	for frame in 3: await physics_frame
	game.player.freeze=true
	for enemy in game._enemies:
		enemy.freeze=true
		enemy.gun.set_physics_process(false)
		enemy.get_node("ArenaBot").set_physics_process(false)
	game.bonus_spawner.set_physics_process(false)
	await shot("playability-wave1")
	game.player.activate_temporary_weapon(load("res://resources/weapons/shotgun.tres"),25)
	var offer:=load("res://scenes/BonusPickup.tscn").instantiate() as BonusPickup
	offer.setup(BonusPickup.Kind.WEAPON,load("res://resources/weapons/rocket_launcher.tres"))
	offer.position=game.player.position+Vector2(55,0)
	game.add_child(offer)
	for frame in 3: await physics_frame
	await shot("playability-keyboard")
	game._using_joypad=true
	await shot("playability-pad")
	# Render a real own mine under the opaque roof, and another next to the car.
	offer.queue_free()
	game.camera.resting_zoom=2.8
	game.camera.maximum_speed_zoom=2.8
	game.camera.snap_to_target()
	for offset in [Vector2.ZERO,Vector2(0,65)]:
		var mine:=load("res://scenes/Bullet.tscn").instantiate() as Bullet
		game.bullets.add_child(mine)
		mine.setup(game.player.position+offset,Vector2.RIGHT,load("res://resources/weapons/mine_layer.tres"),game.player)
	game._reinforcement_timer=999
	await shot("playability-mine")
	print("PLAYABILITY GUI COMPLETE")
	quit()
