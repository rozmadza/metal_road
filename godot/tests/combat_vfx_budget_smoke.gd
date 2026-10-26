extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("VFX BUDGET FAIL: ", label)

func run() -> void:
	var fx := CombatVFX.new()
	root.add_child(fx)
	for i in 70: fx.spawn_impact(Vector2(i, 0))
	check(fx.events.size() == 48, "70 impacts bounded")
	check(fx.events[0].position.x == 22, "same-priority oldest replaced")
	fx.events.clear()
	for i in 70: fx.spawn_explosion(Vector2(i, 0))
	check(fx.events.size() == 48, "70 explosions bounded")
	for i in 70: fx.spawn_impact(Vector2.ZERO)
	check(fx.events.all(func(e): return e.kind == &"explosion"), "sparks cannot evict explosions")
	fx.events.clear()
	fx.spawn_pickup(Vector2(999, 0))
	fx.spawn_explosion(Vector2(998, 0))
	for i in 70: fx.spawn_impact(Vector2(i, 0))
	check(fx.events.size() == 48 and fx.events[0].kind == &"pickup" and fx.events[1].kind == &"explosion", "important effects survive mixed burst")
	fx.spawn_impact(Vector2(997, 0), Color.WHITE, true)
	for i in 70: fx.spawn_impact(Vector2(i, 0))
	check(fx.events.any(func(e): return e.position.x == 997), "large hit survives ordinary impacts")
	fx._process(0.25)
	check(fx.events.size() == 2, "impact TTL expires before important effects")
	fx._process(0.31)
	check(fx.events.is_empty() and not fx.is_processing(), "TTL drains and disables processing")
	fx.spawn_pickup(Vector2.ZERO)
	check(fx.events.size() == 1 and fx.is_processing(), "effects restart after idle")
	fx.free()
	var game := load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	await process_frame
	var world_fx := get_first_node_in_group("combat_vfx") as CombatVFX
	for i in 70: world_fx.spawn_explosion(Vector2(i, 0))
	game._on_retry_requested()
	await process_frame
	check(game._round == 1 and game._alive_enemies() == 2 and game._pending_enemies.size() == 1, "Survival restart restores staged first wave")
	check(world_fx.events.size() <= 48, "budget survives restart")
	game.set_process(false)
	for node in get_nodes_in_group("combatants"):
		node.set_physics_process(false)
		if node is Vehicle:
			node.gun.set_physics_process(false)
			var ai := node.get_node_or_null("ArenaBot")
			if ai: ai.set_physics_process(false)
	# Observe the real per-frame TTL with producers stopped.
	await create_timer(0.7).timeout
	check(world_fx.events.is_empty(), "pre-restart burst expires")
	game.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("VFX BUDGET: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
