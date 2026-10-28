extends Node
## Persistent composition playback. Scene AudioManagers still own all effects.
enum State { MUSIC_MENU, MUSIC_SURVIVAL, MUSIC_ARBITER, MUSIC_RACE }

const MENU = preload("res://assets/music/metal_road_garage_warm_desert_groove_loop.ogg")
const SURVIVAL = preload("res://assets/music/metal_road_apocalyptic_combat_loop_heavier.ogg")
const ARBITER = preload("res://assets/music/metal_road_arbiter_arena_de_combote_loop.ogg")
const LEVELS := [-18.0, -16.0, -17.0, -14.0]

var state := -1
var session := 0
var _owner: WeakRef
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _fade_time := 0.0
var _fade_duration := 0.0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _gains := Vector2.ZERO

func _ready() -> void:
	var settings := ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		for entry in [["Master", "master_volume"], ["Music", "music_volume"]]:
			var bus := AudioServer.get_bus_index(entry[0])
			if bus >= 0:
				var value := float(settings.get_value("settings", entry[1], 1.0))
				AudioServer.set_bus_volume_linear(bus, maxf(value, 0.0001))
				AudioServer.set_bus_mute(bus, value <= 0.0)
	# Inherit the game's pause semantics, including pausing an in-flight fade.
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Composition%d" % index
		player.bus = "Music"
		add_child(player)
		_players.append(player)
	show_menu()

func show_menu() -> void:
	session += 1
	_owner = null
	_request(State.MUSIC_MENU, MENU, 1.5)

func begin(owner: Node, survival: bool, race_stream: AudioStream = null, race_db: float = -14.0) -> int:
	session += 1
	_owner = weakref(owner)
	if survival:
		_request(State.MUSIC_SURVIVAL, SURVIVAL, 1.2)
	else:
		_request(State.MUSIC_RACE, race_stream, 1.2, race_db)
	return session

func set_boss(token: int, active: bool) -> void:
	if not owns(token) or state == State.MUSIC_RACE:
		return
	_request(State.MUSIC_ARBITER if active else State.MUSIC_SURVIVAL,
		ARBITER if active else SURVIVAL, 1.0 if active else 1.5)

func owns(token: int) -> bool:
	return token == session and _owner != null and is_instance_valid(_owner.get_ref()) and _owner.get_ref().is_inside_tree()

func set_race_mix(token: int, pitch: float, db: float) -> void:
	if owns(token) and state == State.MUSIC_RACE:
		_players[_active].pitch_scale = pitch
		_to[_active] = db_to_linear(db)
		if _fade_duration == 0.0:
			_gains = _to
			_apply_gains()

func _request(next: int, stream: AudioStream, duration: float, db: float = 100.0) -> void:
	if stream == null:
		return
	if state == next and _players[_active].playing and _players[_active].stream == stream:
		return
	var previous := state
	state = next
	# Reuse a still-fading track when reversing a transition. With only two
	# slots a third request replaces the quieter slot, never a third player.
	var slot := -1
	for index in 2:
		if _players[index].playing and _players[index].stream == stream:
			slot = index
	if slot < 0:
		slot = 0 if _gains.x <= _gains.y else 1
		_players[slot].stop()
		_gains[slot] = 0.0
		_enable_loop(stream)
		_players[slot].stream = stream
		_players[slot].pitch_scale = 1.0
		_players[slot].volume_linear = 0.0
		_players[slot].play()
	_active = slot
	_from = _gains
	_to = Vector2.ZERO
	_to[slot] = db_to_linear(LEVELS[next] if db == 100.0 else db)
	_fade_time = 0.0
	_fade_duration = duration if previous >= 0 else 0.0
	if _fade_duration == 0.0:
		_gains = _to
		_apply_gains()
		_players[1 - _active].stop()

func _process(delta: float) -> void:
	if _fade_duration <= 0.0:
		return
	_fade_time = minf(_fade_time + delta, _fade_duration)
	var weight := _fade_time / _fade_duration
	# Equal-power interpolation avoids the dip of a linear amplitude fade.
	for index in 2:
		_gains[index] = sqrt(lerpf(_from[index] * _from[index], _to[index] * _to[index], weight))
	_apply_gains()
	if weight >= 1.0:
		_fade_duration = 0.0
		_players[1 - _active].stop()

func _apply_gains() -> void:
	for index in 2:
		_players[index].volume_linear = _gains[index]

static func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		var bytes_per_frame := (2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if stream.stereo else 1)
		stream.loop_begin = 0
		stream.loop_end = int(stream.data.size() / bytes_per_frame)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
