extends SceneTree
## Playable QA entry point: launches Survival directly on the Arbiter wave.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	CareerSession.clear_selection()
	change_scene_to_file("res://scenes/ArenaBattle.tscn")
	await scene_changed
	await process_frame
	var game := current_scene as Survival
	game.start_round(5)
	game.hud.show_message("ТЕСТ · ВОЛНА 5\nЦЕРБЕР И АРБИТР В БОЮ", 2.6)
