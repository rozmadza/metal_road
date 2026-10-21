extends CanvasLayer
class_name ArenaHUD
@onready var readout: VehicleReadout = $Readout
@onready var modules: ModuleStatus = $Readout/LeftDock/Health/Modules
@onready var _message: Label = $Message
@onready var cinematic_fx: CinematicFX = $CinematicFX
@onready var tutorial: TutorialCoach = $Tutorial
@onready var pause_overlay: PauseOverlay = $PauseOverlay
var _message_timer := 0.0

func _ready() -> void:
	_message.visible = false
	get_viewport().size_changed.connect(_apply_adaptive_layout)
	_apply_adaptive_layout()


func _apply_adaptive_layout() -> void:
	var compact: bool = get_viewport().get_visible_rect().size.x < 960.0
	$Top/Panel/Status.add_theme_font_size_override("font_size", 13 if compact else 15)
	%BossPanel.offset_left = 10.0
	%BossPanel.offset_top = 58.0
	%BossPanel.offset_right = 220.0 if compact else 244.0
	%BossPanel.offset_bottom = 108.0
	_message.offset_left = -270.0 if compact else -340.0
	_message.offset_right = 270.0 if compact else 340.0
	_message.offset_top = 60.0
	_message.offset_bottom = 90.0

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
	$Top/Panel/Status.text = "ВОЛНА %d · %s   |   УНИЧТОЖЕНО %d · ОСТАЛОСЬ %d\nСЧЁТ %06d%s" % [round_number, scenario, destroyed, enemies, score, " · КОМБО x%d" % combo if combo > 1 else ""]
	if crew_active > 0 or crew_crushed > 0:
		$Top/Panel/Status.text += " · ЭКИПАЖ СБИТ %d · БЕГУТ %d" % [crew_crushed, crew_active]
	var boss := run_info.get("boss") as Vehicle
	%BossPanel.visible = boss != null and is_instance_valid(boss) and boss.alive
	if %BossPanel.visible:
		%BossHealth.max_value = boss.config.max_health
		%BossHealth.value = boss.health
		var boss_name := String(boss.get_meta("boss_name", boss.config.display_name))
		%BossLabel.text = "%s · %d%%" % [boss_name, roundi(boss.health / maxf(boss.config.max_health, 1.0) * 100.0)]

func show_message(text: String, duration: float) -> void:
	_message.text = text
	_message.visible = true
	_message_timer = duration

func occupied_rects() -> Array[Rect2]:
	var rects := readout.occupied_rects()
	rects.append($Top/Panel.get_global_rect())
	if %BossPanel.visible: rects.append(%BossPanel.get_global_rect())
	if _message.visible: rects.append(_message.get_global_rect())
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
