extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Survival = load("res://scenes/ArenaBattle.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.15).timeout
	var bots := get_nodes_in_group("arena_bots")
	check(bots.size() >= 2, "arena bots spawned")
	if bots.size() > 0:
		var bot_node := bots[0] as ArenaBot
		var bot := bot_node.vehicle
		var target := game.player
		bot.last_attacker = target
		bot.health = bot.config.max_health * 0.2
		bot_node.retreat_health_ratio = 0.5
		var commands := bot_node.get_commands(0.0)
		var away := (bot.global_position - target.global_position).normalized()
		var intended := Vector2.RIGHT.rotated(bot.rotation)
		check(intended.dot(away) > -0.4 or commands["steer"] != 0.0, "critical bot attempts disengage")
		check(bot_node._choose_target() == target, "bot prioritizes recent attacker")
		bot.health = bot.config.max_health
		bot_node._reaction_clock = 0.0
		bot.linear_velocity = Vector2.ZERO
		bot_node._progress_anchor = bot.global_position
		bot_node._stuck_timer = bot_node.stuck_timeout
		var recovery := bot_node.get_commands(0.1)
		check(float(recovery["throttle"]) < 0.0 and absf(float(recovery["steer"])) > 0.5, "stuck bot reverses with an escape turn")
	print("ARENA BOT AI: ", "PASS" if failures == 0 else "FAIL")
	game.free()
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	if ok:
		print("ARENA BOT AI ok: ", label)
	else:
		failures += 1
		printerr("ARENA BOT AI FAIL: ", label)
