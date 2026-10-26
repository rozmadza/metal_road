extends "res://tests/arena_navigation_routes_smoke.gd"
## Read-only production diagnosis. Optional counterfactuals affect this fixture only.
class SeededArena extends Arena:
	var geometry_seed := 4217
	func _prepare_run_variation() -> void:
		super._prepare_run_variation()
		_run_rng.seed = geometry_seed

var options: Dictionary = {}
var rows: Array = []
var padding: Array = []
var wall_start := 0

func option(key: String, fallback: String) -> String:
	return str(options.get(key, fallback))

func run() -> void:
	wall_start = Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() == 2: options[pair[0]] = pair[1]
	LoadoutProfile.path_override = "res://ai-diagnostic-loadout.cfg"
	if option("mode", "full") == "full":
		await super.run()
		return
	seed(int(option("seed", "4217")))
	var arena := SeededArena.new()
	arena.geometry_seed = int(option("seed", "4217"))
	var old := "--old" in OS.get_cmdline_user_args()
	arena.config = load("res://tests/fixtures/scrapyard_1000x800.tres" if old else "res://resources/default_arena.tres")
	root.add_child(arena)
	await physics_frame
	if option("mode", "full") == "destroy":
		var target := Vector2(300,320) if old else Vector2(385,185)
		var car := make_car(arena,"raider",target+Vector2(90,0),target,PI)
		var driver := car.get_node("ArenaBot") as ArenaBot
		for frame in 180: await physics_frame
		var before := state(car,driver,180,target)
		var crate: MapProp
		for node in get_nodes_in_group("arena_obstacles"):
			if node.kind == &"crate" and node.position == arena.config.crates[1]: crate = node
		crate.take_damage(1000)
		for frame in 60: await physics_frame
		rows.append({"label":"destruction_transition","before":before,
			"after":state(car,driver,240,target),"destroyed_position":vector(crate.position) if is_instance_valid(crate) else vector(arena.config.crates[1])})
		# A 55-unit area is too loose for this short route. Tighten this fixture
		# before measuring, so it does not park the car before the precise check.
		options.radius = "18"
		await measure([car],[target],"after_destroy",3600)
		car.free()
		arena.free()
		await process_frame
		quit()
		return
	for index in int(option("pad", "0")): padding.append(RefCounted.new())
	var cars: Array[Vehicle] = []
	var goals: Array[Vector2] = []
	for i in 8:
		var p := Vector2(100+i*110,650 if i%2==0 else 130) if old else Vector2(120+i*165,860 if i%2==0 else 120)
		var goal := Vector2(900-i*100,130 if i%2==0 else 650) if old else Vector2(1280-i*155,120 if i%2==0 else 860)
		goals.append(goal)
		var car := make_car(arena,"raider" if i%2==0 else "bastion",p,goal,(goal-p).angle())
		if option("policy", "native") == "stable":
			var driver := car.get_node("ArenaBot") as ArenaBot
			driver._passing_side = -1.0 if i%2 == 0 else 1.0
			driver._recovery_steer = driver._passing_side
			driver._reaction_interval = 0.28 + (i%4)*0.04
		cars.append(car)
	await measure(cars, goals, "group8", 5400)
	for car in cars:
		if is_instance_valid(car): car.free()
	arena.free()
	padding.clear()
	await process_frame
	print("AI DIAGNOSTIC: COMPLETE ", option("id", "probe"))
	quit()

func vector(value: Vector2) -> Array:
	return [snappedf(value.x,0.001),snappedf(value.y,0.001)]

func state(car: Vehicle, driver: ArenaBot, frame: int, goal: Vector2) -> Dictionary:
	var contacts: Array = []
	for body in car.get_colliding_bodies():
		contacts.append({"name":str(body.name),"parent":str(body.get_parent().name),
			"position":vector(body.global_position),"is_vehicle":body is Vehicle})
	var forward := Vector2.RIGHT.rotated(car.rotation)
	var path: Array = []
	for point in driver._path: path.append(vector(point))
	var traffic: Array = []
	for node in get_nodes_in_group("combatants"):
		var other := node as Vehicle
		if other == null or other == car: continue
		var offset := other.global_position-car.global_position
		if offset.length() > 220: continue
		var other_driver := other.get_node_or_null("ArenaBot") as ArenaBot
		traffic.append({"name":str(other.name),"instance_id":other.get_instance_id(),
			"position":vector(other.position),"speed":other.get_speed(),"rotation":other.rotation,
			"ahead":offset.dot(forward),"lateral":absf(offset.cross(forward)),
			"gap":offset.dot(forward)-(car.config.length+other.config.length)*Vehicle.COLLISION_SCALE.x*0.5,
			"driver_active":other_driver.is_physics_processing() if other_driver != null else false})
	return {"frame":frame,"position":vector(car.position),"speed":car.get_speed(),
		"rotation":car.rotation,"angular_velocity":car.angular_velocity,
		"goal":vector(goal),"intent":str(driver._intent),"intent_goal":vector(driver._intent_goal),
		"route":str(driver._route_status),"resolved":vector(driver._resolved_goal),
		"path":path,"path_index":driver._path_index,"path_origin":vector(driver._path_origin),
		"reverse":driver._reversing,"stuck":driver._stuck_timer,
		"yield_remaining":maxf(0,driver._yield_until-driver._drive_time),
		"yield_cooldown":maxf(0,driver._yield_cooldown-driver._drive_time),
		"yield_goal":vector(driver._yield_goal),"yield_count":driver.yield_manoeuvres,
		"traffic_stall":driver._traffic_stall,
		"peer":str(driver._traffic_peer.name) if is_instance_valid(driver._traffic_peer) else "",
		"throttle":car.throttle,"brake":car.brake,"steer":car.steer,
		"front_room":driver._nav.free_distance(car.position,forward,260.0,car.config.length*Vehicle.COLLISION_SCALE.x*0.5+5.0),
		"rear_room":driver._reverse_room(forward),"contacts":contacts,"traffic":traffic,
		"traffic_speed_cap":driver._traffic_speed(200,forward),"name":str(car.name),
		"point_clear":driver._nav.point_clear(car.position,driver._clearance)}

func save_report() -> void:
	var path := "res://ai-diagnostic-"+option("id","probe")+".json"
	var report := {"options":options,"wall_seconds":(Time.get_ticks_msec()-wall_start)/1000.0,
		"rows":rows,"failures":failures}
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report))

func measure(cars: Array, goals: Array, label: String, frames: int) -> void:
	var actors: Array = []
	var drivers: Array = []
	var geometry: Array = []
	var arena: Arena = (cars[0].get_node("ArenaBot") as ArenaBot).arena
	for node in get_nodes_in_group("arena_obstacles"):
		geometry.append({"kind":str(node.kind),"position":vector(node.position),"rotation":node.rotation})
	for i in cars.size():
		var car: Vehicle = cars[i]
		var driver := car.get_node("ArenaBot") as ArenaBot
		drivers.append(driver)
		actors.append({"index":i,"instance_id":car.get_instance_id(),"side":driver._passing_side,
			"reaction":driver._reaction_interval,"start":vector(car.position),"goal":vector(goals[i]),
			"reached":false,"arrival_frame":-1,"stop_frames":0,"max_stop_frames":0,
			"slow_frames":0,"physical_slow_frames":0,"yield_slow_frames":0,"route_wait_frames":0,
			"reverse_attempts":0,"was_reverse":false,"samples":[]})
	var elapsed := 0
	for frame in frames:
		await physics_frame
		elapsed = frame+1
		for i in cars.size():
			var actor: Dictionary = actors[i]
			if actor.reached: continue
			var car: Vehicle = cars[i]
			var driver: ArenaBot = drivers[i]
			var reverse: bool = driver._reversing > 0
			var changed: bool = reverse != bool(actor.was_reverse)
			if reverse and not actor.was_reverse: actor.reverse_attempts += 1
			actor.was_reverse = reverse
			var slow: bool = car.get_speed() < 12
			actor.stop_frames = int(actor.stop_frames)+1 if slow else 0
			actor.max_stop_frames = maxi(actor.max_stop_frames,actor.stop_frames)
			if slow:
				actor.slow_frames += 1
				if not car.get_colliding_bodies().is_empty(): actor.physical_slow_frames += 1
				if driver._yield_until > driver._drive_time: actor.yield_slow_frames += 1
				if driver._route_status != &"EXACT": actor.route_wait_frames += 1
			if frame%60 == 0 or changed:
				actor.samples.append(state(car,driver,frame,goals[i]))
			if car.position.distance_to(goals[i]) < float(option("radius","55")):
				actor.reached = true
				actor.arrival_frame = frame
				actor.final = state(car,driver,frame,goals[i])
				if option("arrival", "park") == "remove": car.free()
				else:
					driver.set_physics_process(false)
					car.apply_control(0,0.21,0,false)
		# The stock test reapplies the parking brake every frame after arrival.
		for i in cars.size():
			if actors[i].reached and is_instance_valid(cars[i]): cars[i].apply_control(0,0.21,0,false)
		if actors.all(func(actor): return actor.reached): break
	for i in cars.size():
		if not actors[i].reached: actors[i].final = state(cars[i],drivers[i],elapsed,goals[i])
	var passed := actors.all(func(actor): return actor.reached)
	if not passed: failures += 1
	rows.append({"label":label,"frames":elapsed,"limit":frames,"passed":passed,
		"geometry":geometry,"actors":actors})
	print("AI DIAG ",option("id","probe")," ",label," reached=",actors.map(func(actor):return actor.reached),
		" reverses=",actors.map(func(actor):return actor.reverse_attempts)," frames=",elapsed)
	save_report()
