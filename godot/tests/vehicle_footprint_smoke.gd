extends SceneTree

const VEHICLES := [
	"res://resources/vehicles/raider.tres",
	"res://resources/vehicles/viper.tres",
	"res://resources/vehicles/nomad.tres",
	"res://resources/vehicles/marauder.tres",
	"res://resources/vehicles/behemoth.tres",
	"res://resources/vehicles/elite/referee_biker.tres",
]
const TRACKS := [
	"res://resources/iron_circuit.tres",
	"res://resources/dust_spiral.tres",
	"res://resources/broken_crown.tres",
	"res://resources/ashen_crown.tres",
]
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var configs: Array[VehicleConfig] = []
	for path in VEHICLES:
		var config := load(path) as VehicleConfig
		configs.append(config)
		var vehicle := (load("res://scenes/Vehicle.tscn") as PackedScene).instantiate() as Vehicle
		vehicle.config = config
		root.add_child(vehicle)
		var shape := vehicle.get_node("CollisionShape2D").shape as ConvexPolygonShape2D
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		for point in shape.points:
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		var physical := maximum - minimum
		var visible := vehicle.get_visual_size()
		_check(physical.x >= visible.x * 0.9 and physical.x <= visible.x, "%s collision follows visible length" % config.vehicle_id)
		_check(physical.y >= visible.y * 0.9 and physical.y <= visible.y, "%s collision follows visible width" % config.vehicle_id)
		vehicle.free()
	var max_length := 0.0
	var max_width := 0.0
	for config in configs:
		max_length = maxf(max_length, config.length * Vehicle.COLLISION_SCALE.x)
		max_width = maxf(max_width, config.width * Vehicle.COLLISION_SCALE.y)
	for path in TRACKS:
		var track := Track.new()
		track.config = load(path)
		root.add_child(track)
		var grid := track.get_start_grid(6, max_length, max_width)
		_check(grid.size() == 6, "%s has six start positions" % path)
		for index in range(1, grid.size()):
			_check(track.get_progress_along_track(grid[index]) > track.get_progress_along_track(grid[index - 1]), "%s slots preserve start ranking %d" % [path, index])
		var forward := Vector2.RIGHT.rotated(track.get_start_angle())
		var normal := forward.rotated(PI * 0.5)
		for index in grid.size():
			_check(track.is_point_on_track(grid[index], max_width * 0.5 + 5.0), "%s slot %d stays on road" % [path, index])
			for other in range(index + 1, grid.size()):
				var delta: Vector2 = grid[other] - grid[index]
				var separate := absf(delta.dot(forward)) >= max_length + 5.0 or absf(delta.dot(normal)) >= max_width + 5.0
				_check(separate, "%s slots %d/%d do not overlap (forward %.1f, across %.1f)" % [path, index, other, absf(delta.dot(forward)), absf(delta.dot(normal))])
		track.free()
	print("VEHICLE FOOTPRINT: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("VEHICLE FOOTPRINT FAIL: ", label)
