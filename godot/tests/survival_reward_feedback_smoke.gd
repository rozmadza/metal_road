extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var survival: Survival = load("res://scenes/ArenaBattle.tscn").instantiate()
	root.add_child(survival)
	await create_timer(0.15).timeout
	# Wave one now starts with two cars and has a deferred third opponent.
	# Complete the reinforcement before checking the round reward.
	survival._update_reinforcements(5.1)
	await process_frame
	check(survival._pending_enemies.is_empty() and survival._alive_enemies() == 3, "first-wave reinforcement spawned")
	for enemy in survival._enemies:
		enemy._die()
	var message: Label = survival.get_node("HUD/Message")
	check(message.visible, "round reward message visible")
	check("CREDITS" in message.text and "+" in message.text, "round reward amount shown")
	await process_frame
	check(survival._round_over and survival._player_won, "round enters transition state")
	print("SURVIVAL REWARD FEEDBACK: ", "PASS" if failures == 0 else "FAIL")
	survival.free()
	quit(0 if failures == 0 else 1)

func check(ok: bool, label: String) -> void:
	if ok:
		print("SURVIVAL REWARD ok: ", label)
	else:
		failures += 1
		printerr("SURVIVAL REWARD FAIL: ", label)
