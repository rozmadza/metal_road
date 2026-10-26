extends Node2D
class_name MachineGun
## Fires bullets from its parent vehicle. Handles fire rate, spread and the
## active-bullet limit. Bullets are spawned into the node in the "bullets"
## group (the Bullets container in Main), so they stay in the world after the
## vehicle moves.

signal fired

const CREW_AIM_CONE := 0.16

@export var config: WeaponConfig
@export var bullet_scene: PackedScene

var _firing := false
var _cooldown := 0.0
var _bullets_parent: Node
var ammo: int = 0
var reload_remaining: float = 0.0
var muzzle_flash_time := 0.0
## Weapons are match pickups, never part of a vehicle's starting loadout.
var enabled := false


func _ready() -> void:
	if config == null:
		config = WeaponConfig.new()
	ammo = config.magazine_size
	_bullets_parent = get_tree().get_first_node_in_group("bullets")
	if _bullets_parent == null:
		_bullets_parent = get_tree().current_scene


## Called every physics frame by the vehicle with the current fire command.
func set_firing(value: bool) -> void:
	_firing = value and enabled

func set_enabled(value: bool) -> void:
	var was_enabled := enabled
	enabled = value
	if enabled and not was_enabled:
		ammo = config.magazine_size
		reload_remaining = 0.0
	if not enabled:
		_firing = false
		reload_remaining = 0.0


func equip(value: WeaponConfig) -> void:
	if value == null:
		return
	config = value
	enabled = true
	_firing = false
	_cooldown = 0.0
	reload_remaining = 0.0
	ammo = config.magazine_size


func _physics_process(delta: float) -> void:
	if muzzle_flash_time > 0.0:
		muzzle_flash_time = maxf(0.0, muzzle_flash_time - delta)
		queue_redraw()
	_cooldown = maxf(0.0, _cooldown - delta)
	if reload_remaining > 0.0:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		if reload_remaining <= 0.0:
			ammo = config.magazine_size
	if not enabled or not _firing or _cooldown > 0.0 or reload_remaining > 0.0:
		return
	if ammo <= 0:
		_start_reload()
		return
	if _bullets_parent == null:
		_bullets_parent = get_tree().get_first_node_in_group("bullets")
		if _bullets_parent == null:
			_bullets_parent = get_tree().current_scene
	if _bullets_parent == null or bullet_scene == null:
		return
	if _active_bullet_count() >= config.max_active_bullets:
		return
	_shoot()


func _shoot() -> void:
	var shooter := get_parent() as Vehicle
	if shooter == null:
		return
	var forward := Vector2.RIGHT.rotated(shooter.global_rotation)
	var muzzle := get_muzzle_position()
	if config.weapon_type == WeaponConfig.WeaponType.MINE:
		muzzle = shooter.to_global(Vector2(-shooter.config.length * 0.44, 0.0))
	else:
		forward = _crew_aim_direction(shooter, muzzle, forward)
	for projectile_index in config.projectiles_per_shot:
		if _active_bullet_count() >= config.max_active_bullets:
			break
		var direction := forward
		if config.spread > 0.0:
			var spread_ratio := randf_range(-1.0, 1.0)
			if config.projectiles_per_shot > 1:
				spread_ratio = remap(float(projectile_index), 0.0, float(config.projectiles_per_shot - 1), -1.0, 1.0)
			direction = direction.rotated(spread_ratio * config.spread)
		var bullet: Bullet = bullet_scene.instantiate()
		_bullets_parent.add_child(bullet)
		bullet.setup(muzzle, direction, config, shooter)
		bullet.damage *= shooter.get_weapon_damage_multiplier()

	ammo = maxi(0, ammo - 1)
	_cooldown = 1.0 / maxf(0.1, config.fire_rate * shooter.get_weapon_fire_rate_multiplier())
	if ammo <= 0:
		_start_reload()
	muzzle_flash_time = 0.11 if config.weapon_type in [WeaponConfig.WeaponType.ROCKET, WeaponConfig.WeaponType.SHOTGUN] else 0.065
	queue_redraw()
	fired.emit()


func _crew_aim_direction(shooter: Vehicle, muzzle: Vector2, forward: Vector2) -> Vector2:
	var best_direction := forward
	var best_angle := CREW_AIM_CONE
	for node in get_tree().get_nodes_in_group("escaping_crew"):
		var crew := node as EscapingCrew
		if crew == null or not crew._active:
			continue
		var travel_time := muzzle.distance_to(crew.global_position) / maxf(config.bullet_speed, 1.0)
		var aim_point := crew.global_position + crew.escape_direction * crew.run_speed * travel_time
		var to_crew := aim_point - muzzle
		if to_crew.is_zero_approx() or to_crew.length() > config.effective_range:
			continue
		var angle := absf(forward.angle_to(to_crew))
		if angle >= best_angle:
			continue
		var query := PhysicsRayQueryParameters2D.create(muzzle, crew.global_position)
		query.exclude = [shooter.get_rid()]
		query.collide_with_areas = false
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			continue
		best_direction = to_crew.normalized()
		best_angle = angle
	return best_direction


func _start_reload() -> void:
	if reload_remaining <= 0.0:
		reload_remaining = config.reload_time


## The projectile starts inside the front section of the body. Vehicle art can
## therefore contain its own integrated weapon without a separate barrel
## protruding beyond the silhouette.
func get_muzzle_position() -> Vector2:
	var shooter := get_parent() as Vehicle
	if shooter == null or shooter.config == null:
		return global_position
	var body_muzzle := minf(config.muzzle_offset, shooter.config.length * 0.46)
	return shooter.to_global(Vector2(body_muzzle, 0.0))


func _active_bullet_count() -> int:
	var count := 0
	for child in _bullets_parent.get_children():
		if child is Bullet:
			count += 1
	return count


func get_cooldown() -> float:
	return _cooldown


func reset() -> void:
	_firing = false
	_cooldown = 0.0
	reload_remaining = 0.0
	ammo = config.magazine_size
	muzzle_flash_time = 0.0
	queue_redraw()


func ammo_state() -> String:
	if reload_remaining > 0.0:
		return "ПЕРЕЗАРЯДКА %.1f С" % reload_remaining
	return "БОЕЗАПАС %d/%d" % [ammo, config.magazine_size]


func _draw() -> void:
	if muzzle_flash_time <= 0.0 or config == null:
		return
	var shooter := get_parent() as Vehicle
	if shooter == null or shooter.config == null:
		return
	var muzzle_x := minf(config.muzzle_offset, shooter.config.length * 0.46)
	if config.weapon_type == WeaponConfig.WeaponType.MINE:
		muzzle_x = -shooter.config.length * 0.44
	var intensity := clampf(muzzle_flash_time / 0.08, 0.0, 1.0)
	var flash_color := config.bullet_color
	if config.weapon_type == WeaponConfig.WeaponType.EMP:
		draw_arc(Vector2(muzzle_x, 0), 14.0 * intensity, 0, TAU, 12, Color(flash_color, intensity), 2.2, true)
		return
	var length := 24.0 if config.weapon_type in [WeaponConfig.WeaponType.ROCKET, WeaponConfig.WeaponType.SHOTGUN] else 14.0
	var points := PackedVector2Array([Vector2(muzzle_x - 2.0, -5.0 * intensity), Vector2(muzzle_x + length * intensity, 0), Vector2(muzzle_x - 2.0, 5.0 * intensity)])
	draw_colored_polygon(points, Color(flash_color, intensity * 0.9))
	draw_circle(Vector2(muzzle_x + 2.0, 0), 4.0 * intensity, Color(1.0, 0.95, 0.72, intensity))
