extends SceneTree
var rows:Array=[]
var world:Node2D
var target:Vehicle
var failures:=0
func _initialize() -> void:run.call_deferred()
func run() -> void:
	world=Node2D.new();root.add_child(world)
	target=load("res://scenes/Vehicle.tscn").instantiate();world.add_child(target);target.add_to_group("combatants")
	target.freeze=true;target.set_physics_process(false);target.gun.set_physics_process(false)
	await physics_frame
	var cases=["straight","cross","away","zigzag","error5","error10","error20","lost"]
	for variant in ["baseline","A","B_uncapped","B"]:
		for hz in [30,60,120]:
			for distance in [180.0,400.0,700.0]:
				for id in cases:
					for fixed_seed in [4217,7124,1901]:
						seed(fixed_seed)
						var cfg:=load("res://resources/weapons/rocket_launcher.tres").duplicate() as WeaponConfig
						cfg.homing_strength=1.25 if variant=="baseline" else (0.0 if variant=="A" else .3)
						cfg.homing_max_turn=.13962634 if variant=="B" else 0.0
						var start:=Vector2(2000,2000)
						var angle:=deg_to_rad(float(id.trim_prefix("error"))) if id.begins_with("error") else (deg_to_rad(10.0) if id=="lost" else 0.0)
						var dt:float=1.0/hz
						var lateral:=randf_range(-8,8) if id in ["cross","zigzag"] else 0.0
						target.health=target.config.max_health;target.alive=true
						target.position=start+Vector2(distance,lateral)
						var bullet:=Bullet.new();world.add_child(bullet);bullet.setup(start,Vector2.RIGHT.rotated(angle),cfg,null);bullet.set_physics_process(false)
						var min_distance:=INF
						var elapsed:=0.0
						var lost_angle:=INF
						while elapsed<2.3 and not bullet.detonated and not bullet.is_queued_for_deletion():
							elapsed+=dt
							var offset:=Vector2.ZERO
							if id=="cross":offset.y=120*elapsed
							if id=="away":offset.x=120*elapsed
							if id=="zigzag":offset.y=120*(elapsed if elapsed<.6 else 1.2-elapsed)
							target.position=start+Vector2(distance,lateral)+offset
							target.alive=not(id=="lost" and elapsed>.2)
							if id=="lost" and elapsed>.2 and is_inf(lost_angle):lost_angle=bullet.rotation
							bullet._physics_process(dt)
							if id=="lost" and elapsed>.2 and absf(angle_difference(lost_angle,bullet.rotation))>.0001:failures+=1
							min_distance=minf(min_distance,bullet.position.distance_to(target.position))
						rows.append({"variant":variant,"hz":hz,"distance":distance,"case":id,"seed":fixed_seed,"hit":bullet.detonated,"damaged":target.health<target.config.max_health,"flight":elapsed,"turn_deg":rad_to_deg(bullet.homing_turn_used),"miss_center":min_distance,"splash_without_contact":target.health<target.config.max_health and not bullet.detonated})
						if variant=="B" and bullet.homing_turn_used>.13964:failures+=1
						bullet.free()
	FileAccess.open("res://homing-v3-results.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
	world.free();await process_frame
	print("HOMING V3 rows=",rows.size()," failures=",failures)
	quit(0 if failures==0 else 1)
