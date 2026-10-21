extends SceneTree
## Verifies the arena builds its walls/obstacles and provides valid spawns.

var _arena: Arena
var _frames := 0
var _failures := 0


func _initialize() -> void:
	_arena = (load("res://scenes/Arena.tscn") as PackedScene).instantiate()
	root.add_child(_arena)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false

	var bounds := _arena.get_bounds()
	_check(bounds.size == Vector2(1000.0, 800.0), "arena bounds match config")
	_check(_arena.get_obstacles().size() >= 3, "arena has obstacles (%d)" % _arena.get_obstacles().size())

	var spawns := _arena.get_spawn_points(7)
	_check(spawns.size() == 7, "seven spawn anchors returned (%d)" % spawns.size())
	var unique := {}
	for point in spawns:
		unique[point] = true
		_check(_arena.is_inside(point, 10.0), "spawn inside arena %s" % str(point))
	_check(unique.size() == spawns.size(), "spawn anchors are distinct")

	var walls := _arena.get_node_or_null("Walls")
	_check(walls != null, "walls static body exists")
	if walls != null:
		_check(walls.get_child_count() == 4, "four boundary collision shapes")
	var obstacle_collisions := _arena.get_node_or_null("ObstacleCollisions")
	_check(obstacle_collisions != null, "typed obstacle collision container exists")
	if obstacle_collisions != null:
		_check(obstacle_collisions.get_child_count() == _arena.get_obstacles().size(), "one material-aware collider per obstacle")
		for index in obstacle_collisions.get_child_count():
			var body := obstacle_collisions.get_child(index)
			var silhouette := body.get_node_or_null("Silhouette") as CollisionPolygon2D
			_check(silhouette != null and silhouette.polygon.size() >= 4, "obstacle %d uses silhouette collision" % index)
		if obstacle_collisions.get_child_count() > 0:
			var tire_shape := obstacle_collisions.get_child(0).get_node_or_null("Silhouette") as CollisionPolygon2D
			_check(tire_shape != null and tire_shape.polygon.size() >= 12, "round tire heap is not a square collider")
	var obstacle_art: Array[Sprite2D] = []
	for child in _arena.get_children():
		if String(child.name).begins_with("ObstacleArt"):
			obstacle_art.append(child as Sprite2D)
	_check(obstacle_art.size() == _arena.get_obstacles().size(), "one visible sprite per obstacle")
	for index in mini(obstacle_art.size(), _arena.get_obstacles().size()):
		var sprite := obstacle_art[index]
		var visual_size := Vector2(sprite.texture.get_size()) * sprite.scale.abs()
		if absf(sprite.rotation) > 0.1:
			visual_size = Vector2(visual_size.y, visual_size.x)
		var collision_polygon := obstacle_collisions.get_child(index).get_node("Silhouette") as CollisionPolygon2D
		var collision_bounds := Rect2(collision_polygon.polygon[0], Vector2.ZERO)
		for point in collision_polygon.polygon:
			collision_bounds = collision_bounds.expand(point)
		_check(visual_size.x >= collision_bounds.size.x and visual_size.y >= collision_bounds.size.y, "obstacle %d art covers collision" % index)
	var round_small_prop_found := false
	for child in _arena.get_children():
		if child is MapProp and child.kind == &"tire_wall":
			var prop_shape := child.get_node("Collision/Shape") as CollisionShape2D
			round_small_prop_found = prop_shape.shape is CircleShape2D
	_check(round_small_prop_found, "small tire heap uses a circular collider")

	print("ARENA: %d failures" % _failures)
	print("ARENA: %s" % ("PASS" if _failures == 0 else "FAIL"))
	_arena.free()
	quit(0 if _failures == 0 else 1)
	return true


func _check(condition: bool, label: String) -> void:
	if condition:
		print("ARENA ok: ", label)
	else:
		_failures += 1
		print("ARENA FAIL: ", label)
