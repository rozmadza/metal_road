extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("WRECK LAYER ","ok: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func run() -> void:
	# Car is intentionally created first, reproducing the worst draw-order case.
	var car:=load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
	root.add_child(car)
	var arena:=load("res://scenes/Arena.tscn").instantiate() as Arena
	root.add_child(arena)
	var art:=arena.get_node("ObstacleArt") as Sprite2D
	var shadow:=arena.get_node("ObstacleShadow") as Sprite2D
	var footprint:=arena.get_node("ObstacleFootprint") as Polygon2D
	check(footprint.z_index<shadow.z_index and shadow.z_index<art.z_index and art.z_index<car.z_index,"explicit complete layer order")
	check(not arena.y_sort_enabled and art.z_as_relative,"expected canvas inheritance")
	check(arena.get_node("ObstacleCollisions/Obstacle0") is StaticBody2D,"production remains static")
	var polygon:=arena.get_node("ObstacleCollisions/Obstacle0/Silhouette") as CollisionPolygon2D
	check(polygon.polygon==arena._obstacle_polygons[0],"original silhouette retained")
	car.position=arena.config.obstacles[0].get_center()+Vector2(-110,0)
	await physics_frame
	car.linear_velocity=Vector2(120,0);car.apply_control(0.6,0,0)
	for frame in 80:await physics_frame
	check(car.position.x<arena.config.obstacles[0].get_center().x-35,"real car blocked by wreck")
	car.free();arena.free();await process_frame
	print("WRECK LAYER: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
