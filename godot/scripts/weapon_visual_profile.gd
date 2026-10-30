extends Resource
class_name WeaponVisualProfile
## Shared immutable presentation. Empty/invalid clips use the legacy renderer.
## Grids are row-major; pivots are normalized within one frame.

@export_group("Projectile: +X forward, collision origin at pivot")
@export var projectile_body: Texture2D
@export var projectile_size := Vector2(24, 16)
@export var projectile_pivot := Vector2(1.0 / 3.0, 0.5)
@export var exhaust_strip: Texture2D
@export var exhaust_grid := Vector2i.ONE
@export_range(1, 64) var exhaust_frames := 1
@export var exhaust_size := Vector2(22, 12)
@export var exhaust_offset := Vector2(-6, 0)
@export_range(1.0, 60.0) var exhaust_fps := 12.0

@export_group("Launch: follows the existing muzzle timer")
@export var muzzle_sheet: Texture2D
@export var muzzle_grid := Vector2i(3, 2)
@export_range(1, 64) var muzzle_frames := 6
@export var muzzle_size := Vector2(26, 18)
@export var muzzle_pivot := Vector2(1.0 / 6.0, 0.5)

@export_group("Explosion: owned by CombatVFX, not the Bullet tween")
@export var explosion_sheet: Texture2D
@export var explosion_grid := Vector2i(4, 2)
@export_range(1, 64) var explosion_frames := 8
## Extent relative to the existing explosion radius; never affects damage.
@export var explosion_diameter_scale := 2.0


func clip_valid(texture: Texture2D, grid: Vector2i, frames: int) -> bool:
	if texture == null or grid.x < 1 or grid.y < 1 or frames < 1 or frames > grid.x * grid.y:
		return false
	var size := Vector2i(texture.get_size())
	return size.x > 0 and size.y > 0 and size.x % grid.x == 0 and size.y % grid.y == 0


func has_projectile() -> bool:
	return clip_valid(projectile_body, Vector2i.ONE, 1) and projectile_size.x > 0 and projectile_size.y > 0 \
		and clip_valid(exhaust_strip, exhaust_grid, exhaust_frames) and exhaust_size.x > 0 and exhaust_size.y > 0


func has_explosion() -> bool:
	return clip_valid(explosion_sheet, explosion_grid, explosion_frames) and explosion_diameter_scale > 0


func frame_index(progress: float, frames: int) -> int:
	return clampi(int(clampf(progress, 0.0, 1.0) * frames), 0, maxi(0, frames - 1))


func draw_clip(canvas: Node2D, texture: Texture2D, grid: Vector2i, frames: int, progress: float, center: Vector2, size: Vector2, pivot := Vector2(0.5, 0.5)) -> bool:
	if not clip_valid(texture, grid, frames) or size.x <= 0 or size.y <= 0:
		return false
	var frame := frame_index(progress, frames)
	var cell := texture.get_size() / Vector2(grid)
	var source := Rect2(Vector2(frame % grid.x, floori(float(frame) / grid.x)) * cell, cell)
	canvas.draw_texture_rect_region(texture, Rect2(center - size * pivot, size), source)
	return true


func draw_projectile(canvas: Node2D, age: float) -> bool:
	if not has_projectile():
		return false
	var frame := int(age * exhaust_fps) % maxi(1, exhaust_frames)
	draw_clip(canvas, exhaust_strip, exhaust_grid, exhaust_frames, float(frame) / maxi(1, exhaust_frames), exhaust_offset, exhaust_size, Vector2(1, 0.5))
	draw_clip(canvas, projectile_body, Vector2i.ONE, 1, 0.0, Vector2.ZERO, projectile_size, projectile_pivot)
	return true


func draw_muzzle(canvas: Node2D, center: Vector2, progress: float) -> bool:
	return draw_clip(canvas, muzzle_sheet, muzzle_grid, muzzle_frames, progress, center, muzzle_size, muzzle_pivot)


func draw_explosion(canvas: Node2D, center: Vector2, radius: float, progress: float) -> void:
	draw_clip(canvas, explosion_sheet, explosion_grid, explosion_frames, progress, center, Vector2.ONE * radius * explosion_diameter_scale)
