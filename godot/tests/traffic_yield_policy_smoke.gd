extends "res://tests/arena_navigation_routes_smoke.gd"
class ArcGuardDriver extends ArenaBot:
	var open_arc:=false
	func _reverse_room(_forward: Vector2) -> float: return 90.0
	func _reverse_arc_clear(_side: float) -> bool: return open_arc
## Runs unchanged against the before snapshot and current implementation.
func run() -> void:
	var arena:=Arena.new()
	arena.config=load("res://resources/default_arena.tres")
	root.add_child(arena)
	await physics_frame
	var peer:=make_car(arena,"bastion",Vector2(600,860),Vector2(300,860),PI)
	var car:=make_car(arena,"bastion",Vector2(500,860),Vector2(1000,860))
	var occupying:=make_car(arena,"bastion",Vector2(500,774),Vector2(500,774))
	for body in [peer,car,occupying]:
		body.get_node("ArenaBot").set_physics_process(false)
		body.apply_control(0,0.21,0,false)
	await physics_frame
	var driver:=car.get_node("ArenaBot") as ArenaBot
	driver._passing_side=1.0
	driver._drive_time=10.0
	driver._intent_goal=Vector2(1000,860)
	driver._update_traffic_yield(1.0)
	var query:=PhysicsShapeQueryParameters2D.new()
	query.shape=driver._recovery_shape
	query.exclude=[car.get_rid()]
	query.collision_mask=car.collision_mask
	query.transform=Transform2D(car.rotation,driver._yield_goal)
	var overlaps:=car.get_world_2d().direct_space_state.intersect_shape(query)
	var unsafe:=driver._yield_until>driver._drive_time and not overlaps.is_empty()
	print("YIELD POLICY unsafe=",unsafe," goal=",driver._yield_goal," reverse=",driver._reversing," peer_active=",peer.get_node("ArenaBot").is_physics_processing())
	check(not unsafe,"yield destination must fit actual hull and traffic")
	# Intended combat target remains eligible for ramming.
	driver._victim=peer
	check(driver._traffic_speed(120,Vector2.RIGHT)==120,"combat victim is not traffic braking blocker")
	if driver.has_method("_request_reverse"):
		driver.free()
		var guard:=ArcGuardDriver.new()
		guard.arena=arena
		car.add_child(guard)
		guard.set_physics_process(false)
		check(not guard.call("_request_reverse",1.0,0.8),"closed initial arc is rejected")
		guard._drive_time=3.0
		var count: int=guard.get("recovery_requested")
		check(not guard.call("_request_reverse",1.0,0.8) and guard.get("recovery_requested")==count,"unchanged failure is not requested again")
		guard.open_arc=true
		check(guard.call("_request_reverse",1.0,0.8),"cleared side blocker releases failure memory")
		guard._yield_goal=Vector2(700,860)
		guard._yield_until=1.0
		guard._update_traffic_yield(0.0)
		check(guard.call("_failed_yield",Vector2(700,860)),"unreached timed-out yield is remembered")
	for body in [peer,car,occupying]: body.free()
	arena.free()
	print("YIELD POLICY: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
