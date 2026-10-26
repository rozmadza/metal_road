extends SceneTree
## Real rendered physics, scripted actions; not a manual playthrough.
class Driver extends ArenaBot:
	var goal:=Vector2.ZERO
	func _update_intent(_delta: float) -> void: _set_intent(&"route_test",goal)
var report: Dictionary={"group":[],"combat":{}}
func _initialize() -> void: run.call_deferred()
func shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://traffic-"+label+".png")
func run() -> void:
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1280,800)
	LoadoutProfile.path_override="res://traffic-visual-loadout.cfg"
	var arena:=Arena.new()
	arena.config=load("res://resources/default_arena.tres")
	root.add_child(arena)
	var camera:=Camera2D.new()
	camera.position=Vector2(700,500)
	camera.zoom=Vector2.ONE*0.72
	root.add_child(camera)
	camera.make_current()
	var cars: Array[Vehicle]=[]
	var reached: Array[bool]=[]
	for i in 8:
		var p:=Vector2(120+i*165,860 if i%2==0 else 120)
		var goal:=Vector2(1280-i*155,120 if i%2==0 else 860)
		var car:=load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
		car.config=LoadoutProfile.vehicle_config(&"raider" if i%2==0 else &"bastion").duplicate()
		car.config.max_health=50000
		car.config.engine_health=50000
		car.config.wheels_health=50000
		car.position=p
		car.rotation=(goal-p).angle()
		root.add_child(car)
		car.add_to_group("combatants")
		var driver:=Driver.new()
		driver.name="ArenaBot"
		driver.arena=arena
		driver.goal=goal
		driver.external_weapon_control=true
		car.add_child(driver)
		cars.append(car)
		reached.append(false)
	for frame in 5400:
		await physics_frame
		for i in 8:
			var driver:=cars[i].get_node("ArenaBot") as Driver
			if not reached[i] and cars[i].position.distance_to(driver.goal)<55:
				reached[i]=true
				report.group.append({"actor":i,"arrival_seconds":frame/60.0,"requests":driver.recovery_requested,"cancelled":driver.recovery_cancelled,"detours":driver.traffic_detours})
			if reached[i]:
				driver.set_physics_process(false)
				cars[i].apply_control(0,0.21,0,false)
		if frame in [0,600,1200]: await shot("group-"+str(frame))
		if reached.all(func(value):return value): break
	report.group_reached=reached
	await shot("group-final")
	for car in cars: car.free()
	camera.free()
	arena.free()
	await process_frame
	# Stock Survival session and Input actions. Weapons supplied only to this
	# visual scenario so a short observation includes firing and impact VFX.
	var game:=load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	await physics_frame
	var start:=game.player.position
	var travel:=0.0
	var moving_ai_frames:=0
	var weapon:=load("res://resources/default_machine_gun.tres") as WeaponConfig
	game.player.activate_temporary_weapon(weapon)
	Input.action_press("accelerate")
	Input.action_press("fire")
	for frame in 900:
		await physics_frame
		if frame==180: Input.action_press("steer_right",0.28)
		if frame==540: Input.action_release("steer_right")
		travel=maxf(travel,start.distance_to(game.player.position))
		var moving:=0
		for node in get_nodes_in_group("combatants"):
			if node==game.player or not node is Vehicle: continue
			if node.get_speed()>12: moving+=1
			if frame==0: node.activate_temporary_weapon(weapon)
		if moving>=2: moving_ai_frames+=1
		if frame in [180,600,899]: await shot("combat-"+str(frame))
		if not game.player.alive: break
	Input.action_release("accelerate")
	Input.action_release("steer_right")
	Input.action_release("fire")
	report.combat={"max_player_travel":travel,"two_ai_moving_frames":moving_ai_frames,"player_alive":game.player.alive,"player_health":game.player.health}
	game.free()
	await process_frame
	FileAccess.open("res://traffic-visual.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRAFFIC GUI ",JSON.stringify(report))
	quit(0 if reached.all(func(value):return value) and travel>100 and moving_ai_frames>60 else 1)
