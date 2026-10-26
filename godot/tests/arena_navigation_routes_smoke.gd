extends SceneTree

class GoalDriver extends ArenaBot:
	var goal := Vector2.ZERO
	func _update_intent(_delta: float) -> void:
		_set_intent(&"route_test", goal)

var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("ROUTES FAIL: ",label)
func make_car(arena: Arena, id: String, p: Vector2, goal: Vector2, angle: float = 0) -> Vehicle:
	var car := load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
	car.config = (load("res://resources/vehicles/elite/referee_arbiter.tres") if id=="arbiter" else LoadoutProfile.vehicle_config(StringName(id))).duplicate()
	car.config.max_health=50000
	car.config.engine_health=50000
	car.config.wheels_health=50000
	car.config.effects_enabled=false
	car.position=p
	car.rotation=angle
	if id=="arbiter": car.set_meta("boss",true)
	root.add_child(car)
	car.add_to_group("combatants")
	var driver := GoalDriver.new()
	driver.name="ArenaBot"
	driver.arena=arena
	driver.goal=goal
	driver.external_weapon_control=true
	car.add_child(driver)
	return car
func run() -> void:
	seed(4217)
	var arena := Arena.new()
	var old := "--old" in OS.get_cmdline_user_args()
	arena.config=load("res://tests/fixtures/scrapyard_1000x800.tres" if old else "res://resources/default_arena.tres")
	root.add_child(arena)
	await physics_frame
	var lower_start := Vector2(350,650) if old else Vector2(480,860)
	var lower_goal := Vector2(850,650) if old else Vector2(1200,860)
	var center_start := Vector2(350,520) if old else Vector2(500,650)
	var center_goal := Vector2(650,180) if old else Vector2(900,220)
	var anchor := arena.config.obstacles[0].get_center()
	var nav = arena.navigation()
	check(nav.route_result(lower_start,lower_goal,56).status==&"EXACT","exact status")
	check(nav.route_result(lower_start,anchor,72).status==&"NEAREST","blocked center returns nearest")
	check(nav.route_result(Vector2(-100,-100),Vector2(500,360),72).status==&"NONE","invalid origin returns none")
	for id in ["raider","bastion","behemoth","arbiter"]:
		for entry in [
			[center_start,center_goal,"center"],
			[Vector2(120,320) if old else Vector2(150,450),Vector2(410,160) if old else Vector2(520,190),"containers"],
			[Vector2(900,100) if old else Vector2(1280,150),Vector2(900,650) if old else Vector2(1280,860),"bus_outer"],
			[lower_start,lower_goal,"lower"]]:
			var car := make_car(arena,id,entry[0],entry[1],PI if entry[2]=="bus_outer" else 0.0)
			await measure([car],[entry[1]],String(id)+"_"+entry[2],3600)
			car.free()
			await process_frame
	var critical := make_car(arena,"bastion",lower_start,lower_goal)
	critical.damage.wheels=0
	await measure([critical],[lower_goal],"critical_wheels",3600)
	critical.free()
	critical=make_car(arena,"bastion",center_start,center_goal)
	critical.damage.wheels=0
	await measure([critical],[center_goal],"critical_wheels_center",5400)
	critical.free()
	var unreachable := make_car(arena,"arbiter",lower_start,anchor)
	await physics_frame
	var driver := unreachable.get_node("ArenaBot") as ArenaBot
	# Class instance names may be auto-generated for programmatically added drivers.
	if driver==null: driver=unreachable.get_child(unreachable.get_child_count()-1) as ArenaBot
	for frame in 2400: await physics_frame
	check(driver._route_status==&"NEAREST","unreachable status retained")
	check(unreachable.get_speed()<12 and driver._reversing<=0,"unreachable goal stops without reverse cycling")
	print("UNREACHABLE position=",unreachable.position," speed=",unreachable.get_speed())
	unreachable.free()
	var pair: Array[Vehicle]=[
		make_car(arena,"bastion",lower_start,lower_goal),
		make_car(arena,"behemoth",lower_goal,lower_start,PI)]
	await measure(pair,[lower_goal,lower_start],"head_on",3600)
	for car in pair: car.free()
	await process_frame
	var container_top := Vector2(375,160) if old else Vector2(510,190)
	var container_bottom := Vector2(375,500) if old else Vector2(510,700)
	pair=[
		make_car(arena,"bastion",container_top,container_bottom,PI*0.5),
		make_car(arena,"behemoth",container_bottom,container_top,-PI*0.5)]
	await measure(pair,[container_bottom,container_top],"containers_head_on",5400)
	for car in pair: car.free()
	await process_frame
	var group: Array[Vehicle]=[]
	var goals: Array[Vector2]=[]
	for i in 8:
		var p:=Vector2(100+i*110,650 if i%2==0 else 130) if old else Vector2(120+i*165,860 if i%2==0 else 120)
		var goal:=Vector2(900-i*100,130 if i%2==0 else 650) if old else Vector2(1280-i*155,120 if i%2==0 else 860)
		goals.append(goal)
		group.append(make_car(arena,"raider" if i%2==0 else "bastion",p,goal,(goal-p).angle()))
	await measure(group,goals,"group8",5400)
	for car in group: car.free()
	arena.free()
	await process_frame
	print("ARENA ROUTES: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
func measure(cars: Array, goals: Array, label: String, frames: int) -> void:
	var reached: Array=[]
	var stalled: Array=[]
	var longest: Array=[]
	var reverses: Array=[]
	var was_reverse: Array=[]
	for car in cars:
		reached.append(false)
		stalled.append(0)
		longest.append(0)
		reverses.append(0)
		was_reverse.append(false)
	var elapsed:=0
	for frame in frames:
		await physics_frame
		elapsed=frame+1
		for i in cars.size():
			var car: Vehicle=cars[i]
			var driver:=car.get_child(car.get_child_count()-1) as ArenaBot
			if car.position.distance_to(goals[i])<55:
				reached[i]=true
			if reached[i]:
				driver.set_physics_process(false)
				car.apply_control(0,0.21,0,false)
				continue
			stalled[i]=int(stalled[i])+1 if car.get_speed()<12 else 0
			longest[i]=maxi(longest[i],stalled[i])
			var reversing: bool=driver._reversing>0
			if reversing and not was_reverse[i]: reverses[i]+=1
			was_reverse[i]=reversing
		if reached.all(func(v): return v): break
	print("ROUTE ",label," frames=",elapsed," reached=",reached," max_stop_s=",longest.map(func(v): return snappedf(v/60.0,0.01))," reverse_attempts=",reverses)
	for car in cars:
		var driver:=car.get_child(car.get_child_count()-1) as ArenaBot
		print("END ",label," position=",car.position," status=",driver._route_status," resolved=",driver._resolved_goal," yields=",driver.yield_manoeuvres)
	check(reached.all(func(v): return v),label+" physical arrival")
