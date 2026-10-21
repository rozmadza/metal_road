extends Control
class_name VehicleReadout
var player: Vehicle
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
