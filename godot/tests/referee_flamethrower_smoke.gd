extends SceneTree

var failures := 0
var shots := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	CareerSession.clear_selection()
	change_scene_to_file("res://scenes/ArenaBattle.tscn")
	await scene_changed
	await process_frame
	var game := current_scene as Survival
	game.start_round(5)
	game._spawn_referee()
	await physics_frame
	var boss := game._boss
	var referee := boss.get_node("RefereeBoss") as RefereeBoss
	var driver := boss.get_node("ArenaBot") as ArenaBot
	driver.set_physics_process(false)
	boss.freeze = true
	game.player.freeze = true
	boss.global_position = Vector2(500.0, 420.0)
	boss.rotation = 0.0
	game.player.global_position = boss.global_position + Vector2(180.0, 0.0)
	boss.gun.fired.connect(func(): shots += 1)
	referee.flame_state = RefereeBoss.FlameState.COOLDOWN
	referee.flame_timer = 0.0
	for frame in 150:
		await physics_frame
	check(shots >= 3, "real flame projectiles are emitted after warning")
	check(referee.flame_state in [RefereeBoss.FlameState.FIRING, RefereeBoss.FlameState.COOLDOWN], "flame state advances beyond warning")
	print("REFEREE FLAMETHROWER: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(condition: bool, label: String) -> void:
	if condition:
		print("REFEREE FLAMETHROWER ok: ", label)
	else:
		failures += 1
		printerr("REFEREE FLAMETHROWER FAIL: ", label)
