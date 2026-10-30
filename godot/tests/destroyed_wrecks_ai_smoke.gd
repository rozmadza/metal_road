extends "res://tests/arena_navigation_routes_smoke.gd"
const Wreck=preload("res://scripts/destroyed_vehicle_wreck.gd")
class SeededArena extends Arena:
	var fixed_seed:=4217
	func _prepare_run_variation() -> void:
		super._prepare_run_variation()
		_run_rng.seed=fixed_seed
func run() -> void:
	for value in [4217,7124]:
		for count in [1,3,5]:
			seed(value)
			var arena:=SeededArena.new();arena.fixed_seed=value;arena.config=load("res://resources/default_arena.tres");root.add_child(arena)
			var points:=[Vector2(610,740),Vector2(790,740),Vector2(700,540),Vector2(900,340),Vector2(450,420)]
			var covers:Array=[]
			for index in count:
				var source:=load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
				source.config=LoadoutProfile.vehicle_config(&"raider" if index%2==0 else &"bastion").duplicate()
				root.add_child(source);source.position=points[index]
				var wreck:=Wreck.new();wreck.setup(Wreck.snapshot(source));source.free()
				# Normal acceptance uses the production25s lifecycle. An explicit
				# diagnostic can hold cover120s to expose longer-lived gridlocks.
				if "--extended-ttl" in OS.get_cmdline_user_args():wreck.lifetime=120
				arena.add_child(wreck);covers.append(wreck)
			await physics_frame
			check(arena.navigation().route_result(Vector2(480,860),Vector2(700,850),48).status==&"EXACT","hotspot route while covers alive")
			var group:Array[Vehicle]=[];var goals:Array[Vector2]=[]
			for i in 8:
				var start:=Vector2(120+i*165,860 if i%2==0 else 120)
				var goal:=Vector2(1280-i*155,120 if i%2==0 else 860)
				goals.append(goal);group.append(make_car(arena,"raider" if i%2==0 else "bastion",start,goal,(goal-start).angle()))
			await measure(group,goals,"wrecks%d_seed%d"%[count,value],5400)
			# Existing supplies use a fresh snapshot; goal near a marked hotspot.
			var nav=arena.navigation()
			check(nav.route_result(Vector2(480,860),Vector2(700,850),48).status==&"EXACT","hotspot accessible")
			for car in group:car.free()
			arena.free();await process_frame
	print("WRECK AI: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
