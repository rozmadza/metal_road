extends SceneTree
## Manual windowed review helper. Set ARSENAL_REVIEW_WEAPON to a resource id.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	CareerSession.clear_selection()
	change_scene_to_file("res://scenes/Main.tscn")
	await scene_changed
	await process_frame
	var game := current_scene as Game
	var weapon_id := OS.get_environment("ARSENAL_REVIEW_WEAPON")
	if weapon_id.is_empty():
		weapon_id = "rocket_launcher"
	var weapon := load("res://resources/weapons/%s.tres" % weapon_id) as WeaponConfig
	game.vehicle.activate_temporary_weapon(weapon, 999.0)
	for bot in game._bots:
		bot.set_physics_process(false)
		(bot.get_parent() as Vehicle).freeze = true
	game.vehicle.freeze = true
	game.camera.zoom = Vector2(1.9, 1.9)
	game.camera.snap_to_target()
	var pickup := (load("res://scenes/BonusPickup.tscn") as PackedScene).instantiate() as BonusPickup
	pickup.setup(BonusPickup.Kind.WEAPON, weapon, false)
	game.add_child(pickup)
	pickup.global_position = game.vehicle.global_position + Vector2(185, 120)
	game.hud.show_banner("АРСЕНАЛ · %s" % weapon.display_name, 3.0)
