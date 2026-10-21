extends SceneTree
## Windowed comparison board for all weapon deliveries at gameplay scale.

const WEAPONS := [
	"machine_gun", "heavy_machine_gun", "shotgun", "rocket_launcher",
	"mine_layer", "flamethrower", "emp_cannon",
]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	change_scene_to_file("res://scenes/ArenaBattle.tscn")
	await scene_changed
	await process_frame
	var game := current_scene as Survival
	game.set_process(false)
	game.set_physics_process(false)
	game.bonus_spawner.set_physics_process(false)
	game.player.freeze = true
	for enemy in game._enemies:
		if is_instance_valid(enemy):
			enemy.freeze = true
	var origin := game.player.global_position
	var offsets := [
		Vector2(-255, -55), Vector2(-85, -55), Vector2(85, -55), Vector2(255, -55),
		Vector2(-170, 105), Vector2(0, 105), Vector2(170, 105),
	]
	for index in WEAPONS.size():
		var pickup := (load("res://scenes/BonusPickup.tscn") as PackedScene).instantiate() as BonusPickup
		pickup.setup(BonusPickup.Kind.WEAPON, load("res://resources/weapons/%s.tres" % WEAPONS[index]))
		game.add_child(pickup)
		pickup.global_position = origin + offsets[index]
	game.camera.zoom = Vector2(1.15, 1.15)
	game.camera.snap_to_target()
	game.hud.show_message("МАРКЕРЫ ОРУЖИЯ · ПРОВЕРКА ЧИТАЕМОСТИ", 999.0)
