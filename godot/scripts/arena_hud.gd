extends CanvasLayer
class_name ArenaHUD
@onready var readout: VehicleReadout = $Readout
@onready var modules: ModuleStatus = $Readout/LeftDock/Health/Modules
@onready var _message: Label = $Message
@onready var cinematic_fx: CinematicFX = $CinematicFX
@onready var tutorial: TutorialCoach = $Tutorial
@onready var pause_overlay: PauseOverlay = $PauseOverlay
var _message_timer := 0.0
var interaction_prompt: Label
## Opt-in for the expanded scrapyard's edge-clamped camera; Race is untouched.
var avoid_tutorial_overlap := false

func _ready() -> void:
	interaction_prompt = Label.new()
	interaction_prompt.name = "InteractionPrompt"
	interaction_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_prompt.offset_left = -240
	interaction_prompt.offset_right = 240
	interaction_prompt.offset_top = -108
	interaction_prompt.offset_bottom = -82
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_prompt.add_theme_font_size_override("font_size", 16)
	interaction_prompt.add_theme_constant_override("outline_size", 6)
	interaction_prompt.add_theme_color_override("font_outline_color", Color(0.02,0.02,0.02))
	interaction_prompt.hide()
	add_child(interaction_prompt)
	_message.visible = false
	readout.survival_layout = true
	readout._apply_adaptive_layout()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.025, 0.035, 0.04, 0.72)
	panel.border_width_top = 2
	panel.border_color = Color(0.68, 0.47, 0.19, 0.8)
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 5
	panel.content_margin_bottom = 5
	$Top/Panel.add_theme_stylebox_override("panel", panel)
	get_viewport().size_changed.connect(_apply_adaptive_layout)
	_apply_adaptive_layout()


func _apply_adaptive_layout() -> void:
	var compact: bool = get_viewport().get_visible_rect().size.x < 960.0
	$Top/Panel/Status.add_theme_font_size_override("font_size", 12 if compact else 14)
	%BossPanel.offset_left = 10.0
	%BossPanel.offset_top = 84.0
	%BossPanel.offset_right = 220.0 if compact else 244.0
	%BossPanel.offset_bottom = 134.0
	_message.offset_left = -270.0 if compact else -340.0
	_message.offset_right = 270.0 if compact else 340.0
	_message.offset_top = 140.0 if %BossPanel.visible else 88.0
	_message.offset_bottom = _message.offset_top + 30.0

func _process(delta: float) -> void:
	if _message_timer > 0:
		_message_timer -= delta
		if _message_timer <= 0: _message.visible = false

func update_status(player: Vehicle, enemies: int, round_number: int, destroyed: int = 0, run_info: Dictionary = {}) -> void:
	if player == null or player.config == null: return
	cinematic_fx.player = player
	tutorial.setup(player, &"arena")
	readout.update_vehicle(player)
	var scenario := String(run_info.get("scenario", ""))
	var score := int(run_info.get("score", 0))
	var combo := int(run_info.get("combo", 0))
	var crew_active := int(run_info.get("crew_active", 0))
	var crew_crushed := int(run_info.get("crew_crushed", 0))
	var crew_weapon_killed := int(run_info.get("crew_weapon_killed", 0))
	$Top/Panel/Status.text = "ВОЛНА %02d  /  %s     ·     ОСТАЛОСЬ %d\nСЧЁТ %06d   ·   УНИЧТОЖЕНО %d%s" % [round_number, scenario, enemies, score, destroyed, " · КОМБО x%d" % combo if combo > 1 else ""]
	if crew_active > 0 or crew_crushed > 0 or crew_weapon_killed > 0:
		$Top/Panel/Status.text += "\nЭКИПАЖ: НАЕЗД %d · ОРУЖИЕ %d · БЕГУТ %d" % [crew_crushed, crew_weapon_killed, crew_active]
	var boss := run_info.get("boss") as Vehicle
	%BossPanel.visible = boss != null and is_instance_valid(boss) and boss.alive
	_message.offset_top = 140.0 if %BossPanel.visible else 88.0
	_message.offset_bottom = _message.offset_top + 30.0
	if %BossPanel.visible:
		%BossHealth.max_value = boss.config.max_health
		%BossHealth.value = boss.health
		var boss_name := String(boss.get_meta("boss_name", boss.config.display_name))
		%BossLabel.text = "%s · %d%%" % [boss_name, roundi(boss.health / maxf(boss.config.max_health, 1.0) * 100.0)]
	_keep_tutorial_clear(player)

func _keep_tutorial_clear(player: Vehicle) -> void:
	if not avoid_tutorial_overlap or not tutorial.visible: return
	var transform := player.get_global_transform_with_canvas()
	var vertices := player.config.get_body_vertices()
	var car_rect := Rect2(transform * (vertices[0] * Vehicle.COLLISION_SCALE), Vector2.ZERO)
	for vertex in vertices: car_rect = car_rect.expand(transform * (vertex * Vehicle.COLLISION_SCALE))
	# Always compare to the ORIGINAL slot, not last frame's moved panel, to
	# prevent oscillation. Keep below the boss/message strips when moved.
	var original := tutorial.get_global_rect()
	var height := get_viewport().get_visible_rect().size.y
	original.position.y = height - 168
	var blocked := original.intersects(car_rect.grow(20))
	tutorial.offset_top = 180 - height if blocked else -168.0
	tutorial.offset_bottom = 236 - height if blocked else -112.0

func show_message(text: String, duration: float) -> void:
	_message.text = text
	_message.visible = true
	_message_timer = duration

func show_interaction(text: String) -> void:
	interaction_prompt.text = text
	interaction_prompt.visible = not text.is_empty()

func occupied_rects() -> Array[Rect2]:
	var rects := readout.occupied_rects()
	rects.append($Top/Panel.get_global_rect())
	if %BossPanel.visible: rects.append(%BossPanel.get_global_rect())
	if _message.visible: rects.append(_message.get_global_rect())
	if interaction_prompt.visible: rects.append(interaction_prompt.get_global_rect())
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
