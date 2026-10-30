extends SceneTree
const PrototypeArena=preload("res://experiments/movable_wreck_arena.gd")
class GoalDriver extends ArenaBot:
	var goal:=Vector2(900,220)
	func _update_intent(_delta:float) -> void:
		_intent_goal=goal
var failures:=0
var results:Array=[]
func _initialize() -> void: run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("WRECK ","ok: " if ok else "FAIL: ",label)
	if not ok: failures+=1
func arena_new() -> Arena:
	var arena:=PrototypeArena.new();arena.config=load("res://resources/default_arena.tres")
	root.add_child(arena);return arena
func run() -> void:
	for speed in [18.0,210.0]:
		var arena:=arena_new();var wreck:RigidBody2D=arena.wreck
		var origin:=wreck.position
		var car:=load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
		car.position=origin+Vector2(-100,10);root.add_child(car)
		await physics_frame
		car.linear_velocity=Vector2(speed,0)
		var contacts:=0
		var max_speed:=0.0
		for frame in 90:
			await physics_frame
			if wreck.linear_velocity.length()>0.01:contacts+=1
			max_speed=maxf(max_speed,car.linear_velocity.length())
		var displacement:=wreck.position.distance_to(origin)
		car.free()
		for frame in 150:await physics_frame
		results.append({"input_speed":speed,"displacement":displacement,"rotation":wreck.rotation,"settled_speed":wreck.linear_velocity.length(),"car_max_speed":max_speed,"moving_frames":contacts})
		check(wreck.linear_velocity.length()<1,"damping settles body")
		check(max_speed<=speed+2,"no vehicle velocity launch")
		check(wreck.get_node("ObstacleArt").z_index<0,"art below cars")
		if speed>100:check(displacement>1,"physical car moves heavy wreck")
		else:check(displacement<8,"low speed difficult to move")
		arena.free();await process_frame
	check(float(results[1].displacement)>float(results[0].displacement),"strong impact moves more")
	var arena:=arena_new();var wreck:RigidBody2D=arena.wreck
	var origin:=wreck.position
	check(wreck.linear_velocity==Vector2.ZERO and wreck.angular_velocity==0,"recreation restores pose/velocity")
	var nav=arena.navigation()
	check(not nav.point_clear(origin,10),"original current body blocks navigation")
	# Controlled displacement isolates cache refresh from the impact test.
	wreck.freeze=true;wreck.position=origin+Vector2(0,220)
	for frame in 47:await physics_frame
	check(nav.point_clear(origin,10),"old slot leaves no phantom after refresh")
	check(not nav.point_clear(wreck.position,10),"new slot blocks navigation")
	var car:=load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
	car.position=Vector2(500,650);root.add_child(car)
	var driver:=GoalDriver.new();driver.arena=arena;driver.external_weapon_control=true;car.add_child(driver)
	var minimum:=INF
	for frame in 2400:
		await physics_frame
		minimum=minf(minimum,car.position.distance_to(driver.goal))
		if minimum<75:break
	check(minimum<75,"physical AI reaches target around moved body")
	results.append({"AI_min_distance":minimum})
	car.free()
	# CCD and contact response against the existing arena boundary.
	wreck.position=Vector2(1250,850);wreck.freeze=false;wreck.linear_velocity=Vector2(700,0)
	for frame in 120:await physics_frame
	check(wreck.position.x<1400 and wreck.linear_velocity.length()<2,"wall contains and settles wreck")
	arena.free();await process_frame
	FileAccess.open("res://wreck-prototype-results.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print("WRECK PROTOTYPE: ","PASS" if failures==0 else "FAIL"," ",JSON.stringify(results))
	quit(0 if failures==0 else 1)
