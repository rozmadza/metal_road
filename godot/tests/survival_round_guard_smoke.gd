extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("SURVIVAL ROUND GUARD FAIL: ", label)


func run() -> void:
	change_scene_to_file("res://scenes/ArenaBattle.tscn")
	await scene_changed
	var survival := current_scene as Survival
	for enemy in survival._enemies:
		enemy.alive = false
	# Simulate opponents disappearing without their died signal reaching the mode.
	survival._process(0.016)
	check(not survival._round_over, "pending reinforcement prevents premature completion")
	survival._update_reinforcements(5.0)
	await process_frame
	for enemy in survival._enemies: enemy.alive = false
	survival._process(0.016)
	await process_frame
	check(survival._round_over and survival._player_won, "ordinary wave polling completes without boss")
	check(not is_instance_valid(survival._boss), "ordinary wave never creates Arbiter")
	survival.start_round(5)
	for enemy in survival._enemies:
		enemy.alive = false
	survival._process(0.016)
	await process_frame
	check(not survival._round_over, "zero regular opponents starts the finale")
	check(is_instance_valid(survival._boss) and survival._boss.alive, "Arbiter is spawned as the final opponent")
	survival._boss.alive = false
	survival._process(0.016)
	check(survival._round_over, "destroying the Arbiter completes the round")
	check(survival._player_won, "completion is recorded as victory")
	var status: String = survival.get_node("HUD/Top/Panel/Status").text
	check("УНИЧТОЖЕНО 4" in status, "HUD counts three opponents and the Arbiter")
	check("ОСТАЛОСЬ 0" in status, "HUD reports no opponents remaining")
	current_scene.free()
	await create_timer(0.2).timeout
	print("SURVIVAL ROUND GUARD: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
