extends SceneTree
## Human-like play test: drives the car using only the WASD actions, with a
## reaction delay and bang-bang steering, then reports QA metrics + screenshots.

const MAX_FRAMES := 5400      # 90 s safety cap
const TARGET_LAPS := 3

var _game: Node
var _track: Track
var _vehicle: Vehicle
var _rng := RandomNumberGenerator.new()

var _frames := 0
var _wp := 0
var _decision := 0.0
var _decision_interval := 6
var _last_progress := 0.0
var _laps := 0
var _lap_start := 0
var _lap_times: Array[float] = []

var _max_dist := 0.0
var _top_speed := 0.0
var _prev_speed := 0.0
var _impacts := 0
var _stuck_frames := 0
var _max_stuck := 0
var _recovery := 0


func _initialize() -> void:
	_rng.seed = 12345
	_game = load("res://scenes/Main.tscn").instantiate()
	_game.spawn_bots = false
	root.add_child(_game)
	_track = _game.get_node("Track")
	_vehicle = _game.get_node("Vehicle")
	print("PLAYTEST start at ", _vehicle.global_position)


func _set_action(action: String, pressed: bool) -> void:
	if pressed and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not pressed and Input.is_action_pressed(action):
		Input.action_release(action)


func _drive() -> void:
	var pos := _vehicle.global_position
	var waypoint: Dictionary = _track.waypoints[_wp % _track.waypoints.size()]
	if pos.distance_to(waypoint["position"]) <= float(waypoint["radius"]):
		_wp += 1
		waypoint = _track.waypoints[_wp % _track.waypoints.size()]

	var target: Vector2 = waypoint["position"]
	var forward := Vector2.RIGHT.rotated(_vehicle.rotation)
	var err := forward.angle_to((target - pos).normalized())

	# Human-like recovery: after being stuck for a while, back up (S) while
	# steering toward the track.
	if _stuck_frames > 40:
		_recovery = 50
	if _recovery > 0:
		_recovery -= 1
		_set_action("accelerate", false)
		_set_action("brake", true)
		_set_action("steer_right", err > 0.0)
		_set_action("steer_left", err < 0.0)
		return

	# Human-like: only re-decide every few frames, with a small random jitter.
	if _frames % _decision_interval == 0:
		var deadzone := 0.05 + _rng.randf_range(-0.01, 0.02)
		if absf(err) < deadzone:
			_decision = 0.0
		else:
			_decision = signf(err)
		_decision_interval = _rng.randi_range(5, 8)

	_set_action("steer_right", _decision > 0.0)
	_set_action("steer_left", _decision < 0.0)

	# Brake earlier for corners (like a cautious human would).
	var speed := _vehicle.get_speed()
	if absf(err) > 0.45 and speed > 110.0:
		_set_action("accelerate", false)
		_set_action("brake", true)
	else:
		_set_action("brake", false)
		_set_action("accelerate", true)


func _measure() -> void:
	var pos := _vehicle.global_position
	var info := _track.get_closest_segment(pos)
	_max_dist = maxf(_max_dist, info["distance"])
	var speed := _vehicle.get_speed()
	_top_speed = maxf(_top_speed, speed)

	# Sharp speed loss = collision with a wall / another car.
	if _prev_speed - speed > 80.0:
		_impacts += 1
	_prev_speed = speed

	if speed < 5.0 and Input.is_action_pressed("accelerate"):
		_stuck_frames += 1
		_max_stuck = maxi(_max_stuck, _stuck_frames)
	else:
		_stuck_frames = 0

	var progress := _track.get_progress_along_track(pos)
	if progress < _last_progress - _track.get_total_length() * 0.5:
		_laps += 1
		_lap_times.append(float(_frames - _lap_start) / 60.0)
		print("PLAYTEST lap %d done in %.1f s (dist from centre %.1f)" % [_laps, _lap_times[-1], info["distance"]])
		_capture("lap_%d" % _laps)
		_lap_start = _frames
	_last_progress = progress


func _capture(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("/tmp/opencode/play_%s.png" % name)


func _process(_delta: float) -> bool:
	_frames += 1
	_drive()
	_measure()

	if _laps >= TARGET_LAPS or _frames >= MAX_FRAMES:
		_capture("final")
		_report()
		return true
	return false


func _report() -> void:
	var half_width := _track.half_width
	var ok := _laps >= TARGET_LAPS and _max_dist <= half_width + 5.0
	print("---- PLAYTEST REPORT ----")
	print("laps completed : %d" % _laps)
	print("lap times (s)  : %s" % str(_lap_times))
	print("top speed      : %.1f px/s" % _top_speed)
	print("max off-centre : %.1f px (half-width %.1f)" % [_max_dist, half_width])
	print("wall impacts   : %d" % _impacts)
	print("longest stuck  : %d frames" % _max_stuck)
	print("frames         : %d" % _frames)
	print("verdict        : %s" % ("PASS" if ok else "FAIL"))
	print("-------------------------")
	_game.free()
	quit(0 if ok else 1)
