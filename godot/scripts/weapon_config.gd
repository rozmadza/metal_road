extends Resource
class_name WeaponConfig
## Tunable parameters for a weapon. Edit in the Inspector; no code changes.
const VisualProfile = preload("res://scripts/weapon_visual_profile.gd")

enum WeaponType { BALLISTIC, SHOTGUN, ROCKET, MINE, FLAME, EMP }

@export_group("Identity")
@export var weapon_id: StringName = &"machine_gun"
@export var weapon_type: WeaponType = WeaponType.BALLISTIC
@export var display_name: String = "ПУЛЕМЁТ"
@export var tactical_role: String = "СРЕДНЯЯ ДИСТАНЦИЯ"

@export_group("Firing")
## Shots per second.
@export_range(0.5, 50.0, 0.1) var fire_rate: float = 8.0
## Random angular deviation of each shot, in radians.
@export_range(0.0, 0.5, 0.01) var spread: float = 0.03
## Maximum number of bullets alive at once.
@export_range(1, 200, 1) var max_active_bullets: int = 20
## Distance from the vehicle centre to the muzzle.
@export_range(0.0, 100.0, 1.0) var muzzle_offset: float = 22.0
## Projectiles created by one trigger pull. Shotgun ammo is consumed per burst.
@export_range(1, 12, 1) var projectiles_per_shot: int = 1
@export_range(1, 100, 1) var magazine_size: int = 18
@export_range(0.1, 8.0, 0.1) var reload_time: float = 1.4

@export_group("Bullet")
@export_range(50.0, 3000.0, 1.0) var bullet_speed: float = 700.0
@export_range(0.0, 100.0, 0.1) var bullet_damage: float = 5.0
@export_range(0.05, 5.0, 0.01) var bullet_lifetime: float = 0.9
@export_range(1.0, 20.0, 0.5) var bullet_radius: float = 3.0
## Length of the tracer tail drawn behind the bullet.
@export_range(0.0, 50.0, 1.0) var trail_length: float = 14.0
@export var bullet_color: Color = Color(1.0, 0.85, 0.2)
@export_range(0.0, 240.0, 1.0) var splash_radius: float = 0.0
## Radians per second used by guided rockets.
@export_range(0.0, 8.0, 0.1) var homing_strength: float = 0.0
## Total absolute steering budget in radians; zero preserves legacy unlimited steering.
@export_range(0.0, 3.14, 0.01) var homing_max_turn: float = 0.0
## EMP control disruption or mine arming time, depending on the weapon type.
@export_range(0.0, 10.0, 0.1) var effect_duration: float = 0.0
@export_range(0.0, 800.0, 10.0) var effective_range: float = 430.0

@export_group("Presentation")
## Optional shared art; texture below remains the roof/HUD image.
@export var visual_profile: VisualProfile
@export var texture: Texture2D
@export_range(0.15, 0.5, 0.01) var preview_scale: float = 0.28
