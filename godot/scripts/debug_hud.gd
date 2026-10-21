extends CanvasLayer
class_name DebugHUD
@onready var info_label: Label = $Info
@onready var readout: VehicleReadout = $Readout
@onready var modules: ModuleStatus = $Readout/LeftDock/Health/Modules
@onready var minimap: RaceMinimap = $Minimap
@onready var banner: Label = $Banner
@onready var speed_fx: SpeedFX = $SpeedFX
@onready var cinematic_fx: CinematicFX = $CinematicFX
@onready var tutorial: TutorialCoach = $Tutorial
@onready var pause_overlay: PauseOverlay = $PauseOverlay
var player: Vehicle
var _banner_tween: Tween
var _story_panel: PanelContainer
var _story_radio: Label
var _story_radio_tween: Tween
var _story_rival: Vehicle
var _story_marker: PanelContainer

func _ready() -> void:
	get_viewport().size_changed.connect(_apply_adaptive_layout)
	_apply_adaptive_layout()
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.22, 0.08, 0.95)
	fill.set_corner_radius_all(3)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.14, 0.16, 0.17, 0.95)
	background.set_corner_radius_all(3)
	$BossPanel/Row/Health.add_theme_stylebox_override("fill", fill)
	$BossPanel/Row/Health.add_theme_stylebox_override("background", background)


func _apply_adaptive_layout() -> void:
	var compact: bool = get_viewport().get_visible_rect().size.x < 960.0
	$Minimap.offset_left = -172.0 if compact else -205.0
	$Minimap.offset_top = 48.0
	$Minimap.offset_right = -10.0 if compact else -14.0
	$Minimap.offset_bottom = 144.0 if compact else 164.0
	$Top/Panel/Status.add_theme_font_size_override("font_size", 13 if compact else 15)


func configure_race(track: Track, participants: Array[Vehicle]) -> void:
	minimap.setup(track, participants)
	if not participants.is_empty():
		player = participants[0]
		speed_fx.player = player
		cinematic_fx.player = player
		tutorial.setup(player, &"race")


func configure_story_identity(driver: Dictionary, rival: Dictionary) -> void:
	if driver.is_empty() or rival.is_empty():
		return
	if _story_panel != null:
		_story_panel.queue_free()
	_story_panel = PanelContainer.new()
	_story_panel.position = Vector2(16, 56)
	_story_panel.custom_minimum_size = Vector2(238, 0)
	_story_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.065, 0.91)
	style.border_color = Color("c78b47")
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	_story_panel.add_theme_stylebox_override("panel", style)
	add_child(_story_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_story_panel.add_child(column)
	var rivals := HBoxContainer.new()
	rivals.add_theme_constant_override("separation", 5)
	column.add_child(rivals)
	_add_story_face(rivals, driver, Color("62d4d6"))
	var versus := Label.new()
	versus.text = "VS"
	versus.add_theme_font_size_override("font_size", 12)
	versus.add_theme_color_override("font_color", Color("e7bb70"))
	rivals.add_child(versus)
	_add_story_face(rivals, rival, Color("f07562"))
	_story_radio = Label.new()
	_story_radio.visible = false
	_story_radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_radio.custom_minimum_size = Vector2(220, 0)
	_story_radio.add_theme_font_size_override("font_size", 12)
	_story_radio.add_theme_color_override("font_color", Color("e9e9dd"))
	column.add_child(_story_radio)
	_story_marker = PanelContainer.new()
	_story_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var marker_style := StyleBoxFlat.new()
	marker_style.bg_color = Color(0.07, 0.08, 0.09, 0.88)
	marker_style.border_color = Color("e85c4a")
	marker_style.set_border_width_all(1)
	marker_style.set_content_margin_all(3)
	_story_marker.add_theme_stylebox_override("panel", marker_style)
	add_child(_story_marker)
	var marker_label := Label.new()
	marker_label.text = String(rival.get("name", "РЭЙЗОР")).get_slice(" ", 0)
	marker_label.add_theme_font_size_override("font_size", 11)
	marker_label.add_theme_color_override("font_color", Color("ff9d8f"))
	_story_marker.add_child(marker_label)
	_story_marker.hide()


func track_story_rival(rival: Vehicle) -> void:
	_story_rival = rival


func _process(_delta: float) -> void:
	if _story_marker == null or _story_rival == null or not is_instance_valid(_story_rival) or not _story_rival.alive:
		if _story_marker != null:
			_story_marker.hide()
		return
	var point := get_viewport().get_canvas_transform() * _story_rival.global_position
	var bounds := get_viewport().get_visible_rect().size
	if point.x < 35.0 or point.x > bounds.x - 35.0 or point.y < 105.0 or point.y > bounds.y - 45.0:
		_story_marker.hide()
		return
	_story_marker.position = point - Vector2(_story_marker.size.x * 0.5, 48.0)
	_story_marker.show()


func _add_story_face(parent: HBoxContainer, profile: Dictionary, tint: Color) -> void:
	var portrait := TextureRect.new()
	portrait.texture = load(String(profile.get("portrait", ""))) as Texture2D
	portrait.custom_minimum_size = Vector2(34, 34)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	parent.add_child(portrait)
	var name_label := Label.new()
	name_label.text = String(profile.get("name", "")).get_slice(" ", 0)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", tint)
	parent.add_child(name_label)


func show_story_radio(speaker: String, message: String, duration: float = 3.3) -> void:
	if _story_radio == null:
		return
	if _story_radio_tween != null and _story_radio_tween.is_valid():
		_story_radio_tween.kill()
	_story_radio.text = "%s: %s" % [speaker, message]
	_story_radio.modulate.a = 1.0
	_story_radio.show()
	_story_radio_tween = create_tween()
	_story_radio_tween.tween_property(_story_radio, "modulate:a", 0.0, 0.35).set_delay(duration)
	_story_radio_tween.tween_callback(_story_radio.hide)

func update_info(vehicle: Vehicle, _commands: Dictionary, debug_enabled: bool) -> void:
	if vehicle == null or vehicle.config == null:
		return
	player = vehicle
	speed_fx.player = vehicle
	cinematic_fx.player = vehicle
	readout.update_vehicle(vehicle)
	$DebugPanel.visible = debug_enabled
	info_label.visible = debug_enabled
	if debug_enabled:
		info_label.text = "F1 · DEBUG    FPS %d\nSpeed %.1f  Side %.1f\nAngle %.1f°\nPosition %.0f, %.0f" % [Engine.get_frames_per_second(), vehicle.get_speed(), vehicle.get_lateral_speed(), rad_to_deg(vehicle.rotation), vehicle.position.x, vehicle.position.y]

func update_race(position: int, total: int, lap: int, laps: int, elapsed: float, event_status: String = "") -> void:
	if event_status.is_empty():
		$Top/Panel/Status.text = "МЕСТО  %d/%d     КРУГ  %d/%d     ВРЕМЯ  %02d:%05.2f" % [position, total, lap, laps, int(elapsed) / 60, fmod(elapsed, 60)]
	else:
		$Top/Panel/Status.text = "МЕСТО  %d/%d     %s     ВРЕМЯ  %02d:%05.2f" % [position, total, event_status, int(elapsed) / 60, fmod(elapsed, 60)]


func show_banner(message: String, duration: float = 0.75) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	banner.text = message
	banner.modulate = Color.WHITE
	banner.scale = Vector2(0.82, 0.82)
	banner.pivot_offset = banner.size * 0.5
	banner.show()
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, duration).set_delay(maxf(0.2, duration - 0.28))
	_banner_tween.chain().tween_callback(banner.hide)

func occupied_rects(include_debug: bool = false) -> Array[Rect2]:
	var rects := readout.occupied_rects()
	rects.append($Top/Panel.get_global_rect())
	if include_debug: rects.append($DebugPanel.get_global_rect())
	return rects

func impact_flash(amount: float = 1.0) -> void:
	cinematic_fx.flash_damage(amount)

func explosion_flash() -> void:
	cinematic_fx.flash_explosion()

func pickup_flash(color: Color = Color(0.3, 0.9, 1.0)) -> void:
	cinematic_fx.flash_pickup(color)

func emp_flash() -> void:
	cinematic_fx.pulse_emp()

func finish_cinematic(enabled: bool = true) -> void:
	cinematic_fx.set_finish_cinematic(enabled)

func reset_cinematic() -> void:
	cinematic_fx.reset()
	$BossPanel.hide()

func update_boss(name: String, health_ratio: float, phase: int) -> void:
	$BossPanel.show()
	$BossPanel/Row/Name.text = name
	$BossPanel/Row/Health.value = clampf(health_ratio, 0.0, 1.0) * 100.0
	$BossPanel/Row/Phase.text = "ФАЗА %d/3" % phase
