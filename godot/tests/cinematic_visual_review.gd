extends SceneTree
## Windowed review helper for the new audiovisual feedback layer.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	CareerSession.clear_selection()
	change_scene_to_file("res://scenes/Main.tscn")
	await scene_changed
	await process_frame
	var game := current_scene as Game
	for bot in game._bots:
		bot.set_physics_process(false)
		(bot.get_parent() as Vehicle).freeze = true
	game.vehicle.freeze = true
	game.vehicle.activate_temporary_weapon(load("res://resources/weapons/rocket_launcher.tres"), 999.0)
	game.camera.zoom = Vector2(1.45, 1.45)
	game.camera.snap_to_target()
	game.hud.show_banner("КИНЕМАТОГРАФИЧЕСКАЯ ОБРАТНАЯ СВЯЗЬ", 4.0)
	game.hud.impact_flash(22.0)
	game.hud.pickup_flash(Color(0.22, 0.86, 1.0))
	var vfx := game.get_node("CombatVFX") as CombatVFX
	vfx.spawn_explosion(game.vehicle.global_position + Vector2(135, 35), Color(1.0, 0.35, 0.05), 95.0)
	vfx.spawn_impact(game.vehicle.global_position + Vector2(74, -28), Color(1.0, 0.82, 0.25))
	await process_frame
	await process_frame
	game.hud.cinematic_fx.set_process(false)
	vfx.set_process(false)
