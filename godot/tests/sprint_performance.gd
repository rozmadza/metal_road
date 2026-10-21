extends SceneTree
## Rendered six-car stress sample, not a substitute for interactive playtesting.
var game: Survival
var elapsed := 0.0
var samples: Array[float] = []
var peak_bullets := 0
var cars: Array[Vehicle] = []

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	game = load("res://scenes/ArenaBattle.tscn").instantiate()
	game.starting_enemies = 5
	root.add_child(game)
	game.set_physics_process(false)
	game.camera.enabled = false
	var overview := Camera2D.new()
	overview.position = Vector2(500, 400)
	overview.zoom = Vector2(0.65, 0.65)
	game.add_child(overview)
	overview.make_current()
	for node in get_nodes_in_group("combatants"):
		var v := node as Vehicle
		cars.append(v)
		v.take_damage(76)
		v.remove_from_group("combatants")
		v.apply_control(0.7, 0, 0.3, true)
		var ai := v.get_node_or_null("ArenaBot")
		if ai != null: ai.set_physics_process(false)

func _process(delta: float) -> bool:
	if game == null: return false
	elapsed += delta
	if elapsed > 2:
		samples.append(delta * 1000)
		peak_bullets = maxi(peak_bullets, game.bullets.get_child_count())
	if elapsed < 12: return false
	samples.sort()
	var total := 0.0
	for value in samples: total += value
	var summary := "Six cars, critical smoke/fire, continuous fire, arena obstacles; 2s warmup + 10s sample.\nMean %.2f ms, p95 %.2f ms, mean FPS %.1f; peak bullets %d; emitters %d.\n" % [total / samples.size(), samples[int(samples.size() * 0.95)], 1000.0 * samples.size() / total, peak_bullets, cars.size() * 3]
	print(summary)
	FileAccess.open("res://docs/sprints/performance.txt", FileAccess.WRITE).store_string(summary)
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png("res://docs/sprints/arena-preview.png")
	game.free()
	quit()
	return true
