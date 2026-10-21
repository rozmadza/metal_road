extends Node
class_name AudioManager
## Plays music and sound effects from an [AudioConfig] resource.
##
## The three AudioStreamPlayer children (Music, Engine, SFX) are defined in the
## Main scene and can be edited there (bus, volume, effects) like any other
## node. Swapping the actual sounds is done in the AudioConfig resource.

const SURVIVAL_METAL_BASE: AudioStream = preload("res://assets/music/foundry_verdict_base.ogg")
const SURVIVAL_METAL_COMBAT: AudioStream = preload("res://assets/music/foundry_verdict_combat.ogg")
const SURVIVAL_METAL_BOSS: AudioStream = preload("res://assets/music/foundry_verdict_boss.ogg")

@export var config: AudioConfig

@onready var _music: AudioStreamPlayer = $Music
@onready var _engine: AudioStreamPlayer = $Engine
@onready var _sfx: AudioStreamPlayer = $SFX
var _impact: AudioStreamPlayer
var _ui: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _skid: AudioStreamPlayer
var _impact_cooldown := 0.0
var _intensity_target := 0.0
var _intensity := 0.0
var _danger := 0.0
var _critical_latched := false
var _cue_cache: Dictionary = {}
var _biome_layer: AudioStreamPlayer
var _combat_music: AudioStreamPlayer
var _boss_music: AudioStreamPlayer
var _survival_music_enabled := false
var _boss_music_target := 0.0
var _boss_music_intensity := 0.0
var _engine_pitch_base := 0.8
var _engine_pitch_range := 0.7
var _engine_volume_offset_db := 0.0


func _ready() -> void:
	add_to_group("combat_audio")
	_music.bus = "Music"
	_engine.bus = "Engine"
	_sfx.bus = "Weapons"
	_impact = AudioStreamPlayer.new()
	_impact.bus = "Impacts"
	add_child(_impact)
	_ui = AudioStreamPlayer.new()
	_ui.name = "CinematicCues"
	_ui.bus = "UI"
	add_child(_ui)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "RoadWind"
	_ambience.bus = "Environment"
	add_child(_ambience)
	_skid = AudioStreamPlayer.new()
	_skid.name = "TyreSkid"
	_skid.bus = "Environment"
	add_child(_skid)
	_biome_layer = AudioStreamPlayer.new()
	_biome_layer.name = "BiomeLayer"
	_biome_layer.bus = "Music"
	add_child(_biome_layer)
	_combat_music = AudioStreamPlayer.new()
	_combat_music.name = "CombatMusicLayer"
	_combat_music.bus = "Music"
	add_child(_combat_music)
	_boss_music = AudioStreamPlayer.new()
	_boss_music.name = "BossMusicLayer"
	_boss_music.bus = "Music"
	add_child(_boss_music)
	_play_generated_loop(_ambience, _noise_stream(1.4, 0.13, 73), -42.0)
	_play_generated_loop(_skid, _noise_stream(0.8, 0.3, 19), -55.0)
	if config == null:
		return
	_play_loop(_music, config.music, config.music_volume_db)
	_play_loop(_engine, config.engine, config.engine_volume_db)


## Starts three sample-aligned original metal stems. They continue running in
## sync while only their mix changes, so waves and the Arbiter never restart or
## interrupt the riff.
func enable_survival_metal() -> void:
	if config == null:
		return
	_survival_music_enabled = true
	_boss_music_target = 0.0
	_boss_music_intensity = 0.0
	_music.stop()
	_play_loop(_music, SURVIVAL_METAL_BASE, config.music_volume_db - 1.0)
	_play_loop(_combat_music, SURVIVAL_METAL_COMBAT, -38.0)
	_play_loop(_boss_music, SURVIVAL_METAL_BOSS, -60.0)
	_music.pitch_scale = 1.0
	_combat_music.pitch_scale = 1.0
	_boss_music.pitch_scale = 1.0


func set_survival_music_state(boss_active: bool, boss_phase: int = 0) -> void:
	if not _survival_music_enabled:
		return
	_boss_music_target = clampf(0.52 + 0.16 * boss_phase, 0.0, 1.0) if boss_active else 0.0


func set_biome_profile(biome_id: StringName) -> void:
	if _biome_layer == null: return
	if biome_id != &"rust_frontier":
		_biome_layer.stop()
		return
	# A low mechanical two-note pulse gives the frontier its own identity while
	# remaining compatible with the adaptive main theme.
	var stream := _frontier_pulse_stream()
	_play_generated_loop(_biome_layer, stream, -25.0)
	_music.pitch_scale = 0.91


func set_engine_profile(vehicle: VehicleConfig) -> void:
	if vehicle == null:
		return
	_engine_pitch_base = vehicle.engine_pitch_base
	_engine_pitch_range = vehicle.engine_pitch_range
	_engine_volume_offset_db = vehicle.engine_volume_offset_db


func _frontier_pulse_stream() -> AudioStreamWAV:
	var mix_rate := 11025
	var duration := 4.0
	var frames := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8142
	var dust := 0.0
	for frame in frames:
		var time := float(frame) / mix_rate
		var beat := fmod(time, 1.0)
		var envelope := exp(-beat * 7.0)
		var frequency := 58.0 if int(time) % 2 == 0 else 73.0
		dust = lerpf(dust, rng.randf_range(-1.0, 1.0), 0.025)
		var sample := (sin(TAU * frequency * time) * envelope * 0.22 + dust * 0.035) * 32767.0
		data.encode_s16(frame * 2, int(sample))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav


func _play_loop(player: AudioStreamPlayer, stream: AudioStream, volume_db: float) -> void:
	if stream == null:
		return
	_enable_loop(stream)
	player.stream = stream
	player.volume_db = volume_db
	player.play()


## Makes WAV streams loop seamlessly (the imported default is one-shot).
func _enable_loop(stream: AudioStream) -> void:
	var ogg := stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true
		return
	var wav := stream as AudioStreamWAV
	if wav == null or wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return
	var bytes_per_frame := 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
	if wav.stereo:
		bytes_per_frame *= 2
	wav.loop_begin = 0
	wav.loop_end = int(wav.data.size() / bytes_per_frame)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD


func play_fire() -> void:
	if config != null:
		_sfx.pitch_scale = 1.0
		_play_sfx(config.fire)


func play_weapon_fire(weapon: WeaponConfig) -> void:
	if config == null or weapon == null:
		return
	var stream := config.fire
	var pitch := 1.0
	var volume_offset := 0.0
	match weapon.weapon_type:
		WeaponConfig.WeaponType.SHOTGUN:
			pitch = 0.66
			volume_offset = 3.0
		WeaponConfig.WeaponType.ROCKET:
			pitch = 0.82
			volume_offset = 4.0
		WeaponConfig.WeaponType.MINE:
			pitch = 0.52
			volume_offset = -1.0
		WeaponConfig.WeaponType.FLAME:
			pitch = 1.65
			volume_offset = -6.0
		WeaponConfig.WeaponType.EMP:
			pitch = 2.05
			volume_offset = -1.0
	_sfx.pitch_scale = pitch
	_sfx.volume_db = config.sfx_volume_db + volume_offset
	_sfx.stream = stream
	_sfx.play()


func play_weapon_impact(weapon_type: WeaponConfig.WeaponType) -> void:
	if config == null:
		return
	if weapon_type in [WeaponConfig.WeaponType.ROCKET, WeaponConfig.WeaponType.MINE]:
		_impact.pitch_scale = 1.0 if weapon_type == WeaponConfig.WeaponType.ROCKET else 0.78
		_impact.stream = config.explosion
		_impact.volume_db = config.sfx_volume_db
		_impact.play()
	elif weapon_type == WeaponConfig.WeaponType.EMP:
		_impact.pitch_scale = 1.75
		_impact.stream = config.collision
		_impact.volume_db = config.sfx_volume_db - 2.0
		_impact.play()


func play_collision(intensity: float = 1.0) -> void:
	if config == null or config.collision == null or _impact_cooldown > 0:
		return
	_impact_cooldown = config.impact_cooldown
	_impact.stream = config.collision
	_impact.volume_db = config.sfx_volume_db + linear_to_db(clampf(intensity, 0.1, 1.0))
	_impact.play()


func _process(delta: float) -> void:
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	_intensity = lerpf(_intensity, _intensity_target, 1.0 - exp(-2.8 * delta))
	if config != null:
		if _survival_music_enabled:
			_boss_music_intensity = move_toward(_boss_music_intensity, _boss_music_target, delta * (0.75 if _boss_music_target > _boss_music_intensity else 0.5))
			# Preserve the authored tuning. Intensity is expressed by additional
			# stems rather than by pitching the whole composition up and down.
			_music.pitch_scale = 1.0
			_music.volume_db = config.music_volume_db - 1.0 - _boss_music_intensity * 2.0
			_combat_music.volume_db = lerpf(-38.0, -12.0, _intensity) - _boss_music_intensity * 3.0
			_boss_music.volume_db = lerpf(-60.0, -8.5, _boss_music_intensity)
		else:
			_music.pitch_scale = 0.96 + _intensity * 0.09
			_music.volume_db = config.music_volume_db + _intensity * 2.5 - _danger * 1.5
	_ambience.volume_db = lerpf(-42.0, -18.0, _intensity)
	_ambience.pitch_scale = 0.78 + _intensity * 0.65


func play_finish() -> void:
	if config != null:
		_play_sfx(config.finish)
	play_event_cue(&"finish")


func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	_sfx.stream = stream
	_sfx.volume_db = config.sfx_volume_db
	_sfx.play()


## Adjusts engine pitch/volume from a normalized 0..1 intensity.
func set_engine_intensity(intensity: float) -> void:
	if config == null or not _engine.playing:
		return
	var value := clampf(intensity, 0.0, 1.0)
	_engine.pitch_scale = _engine_pitch_base + value * _engine_pitch_range
	_engine.volume_db = config.engine_volume_db + _engine_volume_offset_db + value * 6.0


func set_game_intensity(speed_ratio: float, danger: float = 0.0, critical: bool = false) -> void:
	_danger = clampf(danger, 0.0, 1.0)
	_intensity_target = clampf(speed_ratio * 0.68 + _danger * 0.5, 0.0, 1.0)
	if critical and not _critical_latched:
		play_event_cue(&"critical")
	_critical_latched = critical


func set_skid_intensity(intensity: float) -> void:
	var value := clampf(intensity, 0.0, 1.0)
	_skid.volume_db = lerpf(-55.0, -14.0, value)
	_skid.pitch_scale = 0.78 + value * 0.38


func play_event_cue(kind: StringName) -> void:
	if _cue_cache.has(kind):
		_ui.stream = _cue_cache[kind]
		_ui.volume_db = -2.0 if kind == &"critical" else -5.0
		_ui.play()
		return
	var stream: AudioStreamWAV
	var volume := -5.0
	match kind:
		&"countdown": stream = _tone_stream(660.0, 0.10, 0.28)
		&"start": stream = _tone_stream(880.0, 0.22, 0.32, 1320.0)
		&"pickup": stream = _tone_stream(720.0, 0.18, 0.26, 1120.0)
		&"repair": stream = _tone_stream(520.0, 0.28, 0.25, 920.0)
		&"critical":
			stream = _tone_stream(190.0, 0.34, 0.32, 145.0)
			volume = -2.0
		&"emp": stream = _tone_stream(1180.0, 0.25, 0.23, 310.0)
		&"finish": stream = _tone_stream(620.0, 0.4, 0.22, 1240.0)
		_: stream = _tone_stream(440.0, 0.12, 0.2)
	_cue_cache[kind] = stream
	_ui.stream = stream
	_ui.volume_db = volume
	_ui.play()


func _play_generated_loop(player: AudioStreamPlayer, stream: AudioStreamWAV, volume_db: float) -> void:
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.data.size() / 2)
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _tone_stream(frequency: float, duration: float, amplitude: float, end_frequency: float = -1.0) -> AudioStreamWAV:
	var mix_rate := 22050
	var frames := maxi(1, int(duration * mix_rate))
	var data := PackedByteArray()
	data.resize(frames * 2)
	for frame in frames:
		var t := float(frame) / float(mix_rate)
		var progress := float(frame) / float(frames)
		var hz := frequency if end_frequency <= 0.0 else lerpf(frequency, end_frequency, progress)
		var envelope := sin(PI * progress) * (1.0 - progress * 0.35)
		var sample := int(sin(TAU * hz * t) * amplitude * envelope * 32767.0)
		data.encode_s16(frame * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav


func _noise_stream(duration: float, amplitude: float, seed_value: int) -> AudioStreamWAV:
	var mix_rate := 11025
	var frames := maxi(1, int(duration * mix_rate))
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var filtered := 0.0
	for frame in frames:
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.12)
		data.encode_s16(frame * 2, int(filtered * amplitude * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.data = data
	return wav


func play_explosion() -> void:
	if config == null or config.explosion == null: return
	_impact.pitch_scale = 1.0
	_impact.stream = config.explosion
	_impact.volume_db = config.sfx_volume_db
	_impact.play()
