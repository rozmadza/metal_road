extends "res://tests/ai_navigation_recovery_probe.gd"
## Identical physical replay before/after the fix. Parked peers keep collisions.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=",true,1)
		if pair.size()==2: options[pair[0]]=pair[1]
	wall_start=Time.get_ticks_msec()
	LoadoutProfile.path_override="res://traffic-loadout.cfg"
	for entry in [
		["stationary",Vector2(500,860),0.0,Vector2(640,860),0.0,Vector2(1100,860),false],
		["oblique",Vector2(500,860),0.0,Vector2(640,860),0.85,Vector2(1100,860),false],
		["inactive_priority",Vector2(500,860),0.0,Vector2(640,860),PI,Vector2(1100,860),true],
		["rear_blocked_yield",Vector2(572.835,737.411),-2.072458,Vector2(551.062,655.301),0.150274,Vector2(400,650),false]]:
		var arena:=SeededArena.new()
		arena.geometry_seed=4217
		arena.config=load("res://tests/fixtures/scrapyard_1000x800.tres" if entry[0]=="rear_blocked_yield" else "res://resources/default_arena.tres")
		root.add_child(arena)
		await physics_frame
		var peer: Vehicle
		if entry[6]: peer=make_car(arena,"bastion",entry[3],entry[1],entry[4])
		var car:=make_car(arena,"bastion",entry[1],entry[5],entry[2])
		if peer==null: peer=make_car(arena,"bastion",entry[3],entry[1],entry[4])
		(peer.get_node("ArenaBot") as ArenaBot).set_physics_process(false)
		peer.apply_control(0,0.21,0,false)
		await measure([car],[entry[5]],entry[0],5400)
		car.free()
		peer.free()
		arena.free()
		await process_frame
	print("TRAFFIC REPLAY: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
