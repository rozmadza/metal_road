extends SceneTree
## Opens the real battle scene and clears wave one so the upgrade draft can be
## inspected at the project's normal 1280x720 viewport.

var game: Survival


func _initialize() -> void:
	game = load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	_clear_wave.call_deferred()


func _clear_wave() -> void:
	for enemy in game._enemies:
		enemy.last_attacker = game.player
		enemy.take_damage(99999.0, &"body", game.player)
