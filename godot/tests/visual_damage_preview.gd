extends SceneTree
## Run with a renderer to inspect all damage states and save a review image.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var title := Label.new()
	title.text = "METAL ROAD / SPORT — DAMAGE FOUNDATION"
	title.position = Vector2(24, 20)
	root.add_child(title)
	for i in range(5):
		var v: Vehicle = load("res://scenes/Vehicle.tscn").instantiate()
		root.add_child(v)
		v.position = Vector2(145 + (i % 3) * 250, 190 + (i / 3) * 240)
		v.scale = Vector2(4, 4)
		v.freeze = true
		v.take_damage(i * 25)
		var label := Label.new()
		label.text = ["100% / READY", "75% / SCARRED", "50% / SMOKE", "25% / CRITICAL", "0% / WRECK"][i]
		label.position = v.position + Vector2(-90, 70)
		root.add_child(label)
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/sprints/damage-preview.png")
	for child in root.get_children():
		child.queue_free()
	await process_frame
	var catalog: VehicleCatalog = load("res://resources/vehicle_catalog.tres")
	var fleet_title := Label.new()
	fleet_title.text = "METAL ROAD — FLEET DAMAGE CONSISTENCY / 50%"
	fleet_title.position = Vector2(24, 20)
	root.add_child(fleet_title)
	for i in catalog.vehicles.size():
		var config: VehicleConfig = catalog.vehicles[i]
		var fleet_vehicle: Vehicle = load("res://scenes/Vehicle.tscn").instantiate()
		fleet_vehicle.config = config
		root.add_child(fleet_vehicle)
		fleet_vehicle.position = Vector2(120 + (i % 4) * 215, 170 + (i / 4) * 260)
		fleet_vehicle.scale = Vector2(2.25, 2.25)
		fleet_vehicle.freeze = true
		fleet_vehicle.take_damage(config.max_health * 0.5)
		var fleet_label := Label.new()
		fleet_label.text = config.display_name
		fleet_label.position = fleet_vehicle.position + Vector2(-88, 66)
		root.add_child(fleet_label)
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/sprints/fleet-damage-preview.png")
	for child in root.get_children():
		child.queue_free()
	await process_frame
	for mode in ["MainMenu", "Main"]:
		var scene: Node = load("res://scenes/%s.tscn" % mode).instantiate()
		root.add_child(scene)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/sprints/%s-preview.png" % mode.to_lower())
		scene.queue_free()
		await process_frame
	quit()
