extends Control
class_name VehicleReadout
var player: Vehicle
var survival_layout := false
@onready var modules: ModuleStatus = $LeftDock/Health/Modules
@onready var speed = $LeftDock/Speed/Gauge
@onready var weapon: Label = $Weapon/Content/Value
@onready var weapon_icon: TextureRect = $Weapon/Content/Icon


func _ready() -> void:
	get_viewport().size_changed.connect(_apply_adaptive_layout)
	_apply_adaptive_layout()


func _apply_adaptive_layout() -> void:
	var viewport_width := get_viewport_rect().size.x
	var compact := viewport_width < 960.0
	$LeftDock.offset_left = 10.0 if compact else 14.0
	$LeftDock.offset_top = -74.0 if compact else -80.0
	$LeftDock.offset_bottom = -10.0 if compact else -14.0
	$Weapon.offset_left = -164.0 if compact else -176.0
	$Weapon.offset_top = -74.0 if compact else -80.0
	$Weapon.offset_right = -10.0 if compact else -14.0
	$Weapon.offset_bottom = -10.0 if compact else -14.0
	if survival_layout:
		$LeftDock/Speed.custom_minimum_size = Vector2(72, 64)
		$LeftDock/Health.custom_minimum_size = Vector2(184, 64)
		$LeftDock.offset_top = -82.0
		$Weapon.offset_left = -226.0
		$Weapon.offset_top = -82.0
		weapon.add_theme_font_size_override("font_size", 11)
		weapon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for panel in [$LeftDock/Speed, $LeftDock/Health, $Weapon]:
			var style := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			style.bg_color = Color(0.025, 0.035, 0.04, 0.72)
			style.border_width_left = 1
			style.border_width_bottom = 0
			panel.add_theme_stylebox_override("panel", style)
		speed.numeric_mode = true
		modules.compact_mode = true

func update_vehicle(vehicle: Vehicle) -> void:
	player = vehicle
	var state := vehicle.get_hud_state()
	speed.set_speed(state.speed, vehicle.get_current_max_speed())
	weapon_icon.texture = state.weapon_texture
	weapon_icon.visible = state.weapon_texture != null
	weapon.text = "%s\n%s\n%s" % [state.weapon_name, state.weapon_state, state.weapon_role if state.weapon_texture != null else state.passive_state]
	modules.update_state(state)

func occupied_rects() -> Array[Rect2]:
	return [$LeftDock/Speed.get_global_rect(), $LeftDock/Health.get_global_rect(), $Weapon.get_global_rect()]
