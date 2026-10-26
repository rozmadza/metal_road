extends Area2D
class_name BonusPickup

const SUPPLY_CRATE := preload("res://assets/bonuses/supply_crate.png")

signal collected(pickup: BonusPickup, vehicle: Vehicle)

enum Kind { WEAPON, REPAIR, SPEED_BOOST, RAM_BOOST }

@export var kind: Kind = Kind.WEAPON
@export var weapon_duration: float = 25.0
@export var speed_boost_duration: float = 8.0
@export var ram_boost_duration: float = 9.0
@export var weapon_config: WeaponConfig

var armed := true
var collected_once := false
var _phase := 0.0
var _badge: Label


func _ready() -> void:
	add_to_group("bonus_pickups")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	monitoring = armed
	_build_badge()
	_update_badge()
	queue_redraw()


func setup(new_kind: Kind, new_weapon: WeaponConfig = null, is_armed: bool = true) -> void:
	kind = new_kind
	weapon_config = new_weapon
	armed = is_armed
	if is_node_ready():
		monitoring = armed
		_update_badge()
	queue_redraw()


func set_armed(value: bool) -> void:
	armed = value
	if is_node_ready():
		monitoring = value
		_update_badge()
	queue_redraw()


func _process(delta: float) -> void:
	_phase += delta
	rotation = sin(_phase * 1.7) * 0.08
	var pulse_speed := 5.2 if armed else 2.4
	scale = Vector2.ONE * (1.0 + sin(_phase * pulse_speed) * (0.06 if armed else 0.035))
	queue_redraw()


func collect(vehicle: Vehicle, confirm_weapon_swap: bool = false) -> bool:
	if not armed or collected_once or is_queued_for_deletion() or vehicle == null or not vehicle.alive:
		return false
	var survival_player := bool(vehicle.get_meta("survival_pickups", false))
	if survival_player and kind == Kind.WEAPON and vehicle.has_temporary_weapon() and not confirm_weapon_swap:
		return false
	collected_once = true
	match kind:
		Kind.WEAPON:
			vehicle.activate_temporary_weapon(weapon_config, weapon_duration)
		Kind.REPAIR:
			# Preserve the existing engine/wheels repair and feedback contract.
			vehicle.repair(vehicle.config.max_health if survival_player else 28.0)
		Kind.SPEED_BOOST:
			vehicle.activate_boost(speed_boost_duration)
		Kind.RAM_BOOST:
			vehicle.activate_ram_boost(ram_boost_duration)
	collected.emit(self, vehicle)
	queue_free()
	return true


func _on_body_entered(body: Node) -> void:
	collect(body as Vehicle)


static func weapon_offer_for(vehicle: Vehicle) -> BonusPickup:
	var nearest: BonusPickup
	var distance := INF
	for node in vehicle.get_tree().get_nodes_in_group("bonus_pickups"):
		var pickup := node as BonusPickup
		if pickup == null or pickup.is_queued_for_deletion() or not pickup.armed or pickup.collected_once or pickup.kind != Kind.WEAPON:
			continue
		if not pickup.overlaps_body(vehicle): continue
		var d := vehicle.global_position.distance_squared_to(pickup.global_position)
		if d < distance:
			distance = d
			nearest = pickup
	return nearest


static func kind_label(value: Kind) -> String:
	match value:
		Kind.WEAPON:
			return "ОРУЖИЕ"
		Kind.REPAIR:
			return "РЕМОНТ"
		Kind.SPEED_BOOST:
			return "УСКОРЕНИЕ"
		Kind.RAM_BOOST:
			return "УСИЛЕННЫЙ ТАРАН"
	return "БОНУС"


func _kind_color() -> Color:
	match kind:
		Kind.WEAPON:
			return weapon_accent(weapon_config)
		Kind.REPAIR:
			return Color("69d47b")
		Kind.SPEED_BOOST:
			return Color("43c8f5")
		Kind.RAM_BOOST:
			return Color("ff9e2c")
	return Color.WHITE


static func weapon_badge(weapon: WeaponConfig) -> String:
	if weapon == null:
		return "ОРУЖИЕ"
	match weapon.weapon_id:
		&"machine_gun":
			return "ПУЛЕМЁТ"
		&"heavy_machine_gun":
			return "ТЯЖ. ПУЛЕМЁТ"
		&"shotgun":
			return "ДРОБОВИК"
		&"rocket_launcher":
			return "РАКЕТЫ"
		&"mine_layer":
			return "МИНЫ"
		&"flamethrower":
			return "ОГНЕМЁТ"
		&"emp_cannon":
			return "ЭМИ-ПУШКА"
	return weapon.display_name


static func weapon_accent(weapon: WeaponConfig) -> Color:
	if weapon == null:
		return Color("ef5350")
	match weapon.weapon_id:
		&"machine_gun":
			return Color("f1b84b")
		&"heavy_machine_gun":
			return Color("ef5350")
		&"shotgun":
			return Color("ff8a3d")
		&"rocket_launcher":
			return Color("f3d45a")
		&"mine_layer":
			return Color("bd76ed")
		&"flamethrower":
			return Color("ff651f")
		&"emp_cannon":
			return Color("45d8ee")
	return Color("ef5350")


func _build_badge() -> void:
	_badge = Label.new()
	_badge.name = "TypeBadge"
	_badge.position = Vector2(-38.0, 20.0)
	_badge.size = Vector2(76.0, 18.0)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override("font_size", 11)
	_badge.add_theme_constant_override("outline_size", 4)
	_badge.add_theme_color_override("font_outline_color", Color(0.015, 0.018, 0.02, 0.98))
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)


func _update_badge() -> void:
	if _badge == null:
		return
	_badge.visible = kind == Kind.WEAPON
	_badge.text = weapon_badge(weapon_config)
	_badge.add_theme_color_override("font_color", Color.WHITE if armed else Color(0.58, 0.6, 0.6, 0.85))


func _draw() -> void:
	var edge := _kind_color()
	var alpha := 0.22 if armed else 0.09
	# The luminous field communicates the intentionally generous collection
	# radius, so players do not need to thread the exact centre of the icon.
	draw_circle(Vector2.ZERO, 45.0, Color(edge, alpha))
	if not armed:
		draw_arc(Vector2.ZERO, 49.0, -PI * 0.75, PI * 0.75, 24, Color(edge, 0.55), 2.0, true)
		edge = Color(edge, 0.55)
	if kind == Kind.WEAPON:
		# The old 27 px roof module disappeared into the crate engraving. A dark
		# display plate, a much larger silhouette and a text badge make the exact
		# weapon readable at the normal arena camera scale.
		var crate_tint := Color(0.34, 0.29, 0.25, 0.92) if armed else Color(0.3, 0.3, 0.3, 0.62)
		draw_texture_rect(SUPPLY_CRATE, Rect2(-31, -31, 62, 62), false, crate_tint)
		draw_rect(Rect2(-31, -22, 62, 41), Color(0.018, 0.022, 0.025, 0.9), true)
		draw_rect(Rect2(-31, -22, 62, 41), Color(edge, 0.9 if armed else 0.42), false, 2.0)
		draw_rect(Rect2(-29, 15, 58, 4), Color(edge, 0.95 if armed else 0.38), true)
		if weapon_config != null and weapon_config.texture != null:
			var source := Vector2(weapon_config.texture.get_size())
			var target := Vector2(54.0, 54.0 * source.y / maxf(source.x, 1.0))
			if target.y > 32.0:
				target *= 32.0 / target.y
			var weapon_rect := Rect2(Vector2(-target.x * 0.5, -target.y * 0.5 - 2.0), target)
			draw_texture_rect(weapon_config.texture, Rect2(weapon_rect.position + Vector2(2, 2), weapon_rect.size), false, Color(0, 0, 0, 0.85))
			draw_texture_rect(weapon_config.texture, weapon_rect, false, Color.WHITE if armed else Color(0.55, 0.55, 0.55, 0.75))
		draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 32, Color(edge, 0.95 if armed else 0.4), 2.5, true)
	else:
		var crate_tint := Color(edge, 1.0).lerp(Color.WHITE, 0.58) if armed else Color(0.42, 0.43, 0.42, 0.72)
		draw_texture_rect(SUPPLY_CRATE, Rect2(-25, -25, 50, 50), false, crate_tint)
		draw_arc(Vector2.ZERO, 29.0, 0.0, TAU, 28, Color(edge, 0.86 if armed else 0.4), 2.0, true)
