extends Arena
## Opt-in sandbox with the unchanged default layout and one movable body.
## Not referenced by any shipped scene or ArenaConfig.
const Wreck = preload("res://experiments/movable_wreck.gd")
var wreck: RigidBody2D

func _create_collision() -> void:
	super._create_collision()
	get_node("ObstacleCollisions/Obstacle0").free()
	var center:=config.obstacles[0].get_center()
	wreck=Wreck.new();wreck.name="ExperimentalWreck";wreck.position=center
	var shape:=CollisionPolygon2D.new()
	var polygon:=PackedVector2Array()
	for point in _obstacle_polygons[0]: polygon.append(point-center)
	shape.polygon=polygon;wreck.add_child(shape)
	var bounds:=Rect2(polygon[0],Vector2.ZERO)
	for point in polygon: bounds=bounds.expand(point)
	wreck.size=bounds.size/Vector2(0.96,0.92)
	add_child(wreck)

func _create_obstacle_visuals() -> void:
	super._create_obstacle_visuals()
	# First slot's visuals move with its actual body. Other slots remain intact.
	for prefix in ["ObstacleArt","ObstacleShadow","ObstacleFootprint"]:
		var node:=get_node(NodePath(prefix)) as Node2D
		node.reparent(wreck,true)

func get_navigation_obstacles() -> Array[Rect2]:
	var result:=super.get_navigation_obstacles()
	result.remove_at(0)
	return result
