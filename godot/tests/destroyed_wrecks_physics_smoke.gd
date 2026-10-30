extends SceneTree
const Wreck=preload("res://scripts/destroyed_vehicle_wreck.gd")
var failures:=0
var rows:Array=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("WRECK PHYS ","ok: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func run() -> void:
	for id in [&"raider",&"behemoth"]:
		for speed in [18.0,165.0]:
			var arena:=load("res://scenes/Arena.tscn").instantiate() as Arena;root.add_child(arena)
			var source:=load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
			source.config=LoadoutProfile.vehicle_config(&"bastion").duplicate();root.add_child(source)
			source.position=Vector2(700,850)
			var wreck:=Wreck.new();wreck.setup(Wreck.snapshot(source));source.free();arena.add_child(wreck)
			var car:=load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
			car.config=LoadoutProfile.vehicle_config(id).duplicate()
			car.position=wreck.position-Vector2((car.config.length+wreck.config.length)*Vehicle.COLLISION_SCALE.x*0.5+2,-10)
			root.add_child(car)
			var counts:={"contacts":0,"inside":0}
			car.body_entered.connect(func(body):
				if body==wreck:counts.contacts+=1)
			await physics_frame
			car.linear_velocity=Vector2(speed,0)
			for frame in 100:
				await physics_frame
				if Geometry2D.is_point_in_polygon(wreck.to_local(car.position),wreck.hull.points):counts.inside+=1
			var impact_distance:=wreck.position.distance_to(Vector2(700,850))
			car.apply_control(0.7,0,0)
			for frame in 100:await physics_frame
			var pushed:=wreck.position.distance_to(Vector2(700,850))
			check(counts.contacts>0 and counts.inside==0,"solid contact "+String(id))
			check(pushed>impact_distance+1,"continued pushing "+String(id))
			car.free()
			for frame in 150:await physics_frame
			check(wreck.linear_velocity.length()<1 and absf(wreck.angular_velocity)<0.1,"settled after release")
			check(absf(wreck.rotation)>0.001,"off-axis rotation")
			rows.append({"car":id,"speed":speed,"impact_displacement":impact_distance,"pushed":pushed,"angle":wreck.rotation,"settled_speed":wreck.linear_velocity.length(),"contacts":counts.contacts,"car_center_inside_frames":counts.inside})
			# A second heavy vehicle also shares physical contacts, not exceptions.
			var second:=load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
			second.config=LoadoutProfile.vehicle_config(&"behemoth").duplicate();second.position=wreck.position+Vector2(120,0);second.rotation=PI
			root.add_child(second);second.apply_control(1,0,0)
			for frame in 100:await physics_frame
			check(second.position.is_finite() and wreck.linear_velocity.length()<=121,"second car stable")
			second.free()
			wreck.freeze=true;wreck.position=Vector2(1280,850);wreck.freeze=false;wreck.linear_velocity=Vector2(120,0)
			for frame in 120:await physics_frame
			check(wreck.position.x<1400,"wall blocks wreck")
			arena.free();await process_frame
	FileAccess.open("res://wreck-physics-results.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	print("WRECK PHYSICS: ","PASS" if failures==0 else "FAIL"," ",JSON.stringify(rows))
	quit(0 if failures==0 else 1)
