extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("HUD FAIL: ", label)
func run() -> void:
	for resolution in [Vector2i(800, 600), Vector2i(1024, 768), Vector2i(1366, 768)]:
		for scene in ["Main", "ArenaBattle"]:
			var view := SubViewport.new()
			view.size = resolution
			root.add_child(view)
			var game: Node = load("res://scenes/%s.tscn" % scene).instantiate()
			if scene == "Main": game.spawn_bots = false
			view.add_child(game)
			await physics_frame
			await process_frame
			await process_frame
			var v: Vehicle = game.vehicle if scene == "Main" else game.player
			game.set_physics_process(false)
			var hud: CanvasLayer = game.hud
			if scene == "Main": hud.update_info(v, {}, true)
			else: hud.update_status(v, 2, 1)
			check(hud.readout.player == v, "actual player bound")
			v.linear_velocity = Vector2(128, 0)
			v.take_damage(20)
			v.take_damage(10, &"engine")
			if scene == "Main": hud.update_info(v, {}, true)
			else: hud.update_status(v, 2, 1)
			check("128" in hud.readout.speed.text, "runtime speed")
			check(hud.modules.bars[0].value < 100 and hud.modules.bars[0].value > 0, "runtime body")
			check(hud.modules.bars[1].value < 100 and hud.modules.bars[2].value < 100, "runtime modules")
			var player_rect := Rect2(v.get_global_transform_with_canvas().origin - Vector2(22, 14), Vector2(44, 28))
			var rects: Array[Rect2] = hud.occupied_rects()
			var lower_rects: Array[Rect2] = hud.readout.occupied_rects()
			for lower_rect in lower_rects:
				check(lower_rect.size.x <= 180.0 and lower_rect.size.y <= 80.0, "%s compact lower HUD module %s" % [scene, lower_rect.size])
			for first in lower_rects.size():
				for second in range(first + 1, lower_rects.size()):
					check(not lower_rects[first].intersects(lower_rects[second]), "%s lower HUD modules do not overlap" % scene)
			for rect in rects:
				check(not rect.intersects(player_rect), "%s %s spawn unobstructed" % [scene, resolution])
				check(not rect.has_point(Vector2(resolution) / 2), "center unobstructed")
				check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(rect), "within viewport")
			if scene == "Main":
				var debug_rect: Rect2 = hud.get_node("DebugPanel").get_global_rect()
				for rect in rects: check(not debug_rect.intersects(rect), "F1 separate from HUD")
			view.free()
	print("HUD RACE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
