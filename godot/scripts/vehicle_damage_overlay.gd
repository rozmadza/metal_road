extends Node2D
class_name VehicleDamageOverlay
## Texture-clipped damage layer. Every mark is masked by the vehicle sprite's
## alpha, so scratches and soot can never look like objects lying on the roof.

var vehicle: Vehicle
var _material: ShaderMaterial
static var _shared_shader: Shader


func setup(value: Vehicle) -> void:
	vehicle = value
	_material = ShaderMaterial.new()
	if _shared_shader == null:
		_shared_shader = _build_shader()
	_material.shader = _shared_shader
	material = _material
	z_index = 0
	queue_redraw()


func _process(_delta: float) -> void:
	if vehicle == null or vehicle.config == null:
		visible = false
		return
	var body_damage := 1.0 - vehicle.damage.ratio(&"body")
	var engine_damage := 1.0 - vehicle.damage.ratio(&"engine")
	var wheel_damage := 1.0 - vehicle.damage.ratio(&"wheels")
	visible = body_damage > 0.01 or engine_damage > 0.18 or wheel_damage > 0.18
	_material.set_shader_parameter("body_damage", body_damage)
	_material.set_shader_parameter("engine_damage", engine_damage)
	_material.set_shader_parameter("wheel_damage", wheel_damage)
	_material.set_shader_parameter("damage_tint", vehicle.config.damage_color)


func _draw() -> void:
	if vehicle == null or vehicle.config == null or vehicle.config.texture == null:
		return
	var size := vehicle.get_visual_size()
	draw_texture_rect(vehicle.config.texture, Rect2(-size * 0.5, size), false)


func _build_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform float body_damage : hint_range(0.0, 1.0) = 0.0;
uniform float engine_damage : hint_range(0.0, 1.0) = 0.0;
uniform float wheel_damage : hint_range(0.0, 1.0) = 0.0;
uniform vec4 damage_tint : source_color = vec4(0.14, 0.08, 0.04, 0.8);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h);
}

float scratch(vec2 uv, vec2 a, vec2 b, float width) {
	return 1.0 - smoothstep(width, width * 2.2, segment_distance(uv, a, b));
}

float impact_mark(vec2 uv, vec2 center, float radius) {
	vec2 aspect = vec2(1.0, 1.75);
	float d = length((uv - center) * aspect);
	float core = 1.0 - smoothstep(radius * 0.22, radius * 0.48, d);
	float ring = smoothstep(radius * 0.42, radius * 0.62, d) * (1.0 - smoothstep(radius * 0.62, radius, d));
	return max(core, ring * 0.7);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a < 0.04) {
		COLOR = vec4(0.0);
	} else {
		float first_stage = smoothstep(0.08, 0.28, body_damage);
		float second_stage = smoothstep(0.32, 0.58, body_damage);
		float critical = smoothstep(0.62, 0.82, body_damage);
		float wreck = smoothstep(0.88, 1.0, body_damage);

		float fine_scratches = 0.0;
		fine_scratches = max(fine_scratches, scratch(UV, vec2(0.28, 0.42), vec2(0.48, 0.49), 0.0024));
		fine_scratches = max(fine_scratches, scratch(UV, vec2(0.39, 0.58), vec2(0.61, 0.51), 0.0021));
		fine_scratches = max(fine_scratches, scratch(UV, vec2(0.55, 0.39), vec2(0.71, 0.46), 0.0018));
		fine_scratches *= first_stage;

		float chip_noise = smoothstep(0.7, 0.9, value_noise(UV * vec2(54.0, 34.0)));
		float center_mask = 1.0 - smoothstep(0.17, 0.42, length((UV - vec2(0.52)) * vec2(1.0, 1.7)));
		float paint_chips = chip_noise * center_mask * second_stage;

		float hit_a = impact_mark(UV, vec2(0.34, 0.47), 0.043) * second_stage;
		float hit_b = impact_mark(UV, vec2(0.65, 0.55), 0.035) * critical;
		float impact_damage = max(hit_a, hit_b);

		vec2 soot_aspect = vec2(1.0, 1.8);
		float front_soot = 1.0 - smoothstep(0.06, 0.21, length((UV - vec2(0.68, 0.5)) * soot_aspect));
		front_soot *= smoothstep(0.34, 0.72, engine_damage);
		front_soot *= mix(0.55, 1.0, value_noise(UV * 22.0));

		float wheel_scuffs = 0.0;
		wheel_scuffs = max(wheel_scuffs, scratch(UV, vec2(0.25, 0.36), vec2(0.38, 0.4), 0.003));
		wheel_scuffs = max(wheel_scuffs, scratch(UV, vec2(0.6, 0.63), vec2(0.76, 0.58), 0.003));
		wheel_scuffs *= smoothstep(0.35, 0.72, wheel_damage);

		float broad_soot = (0.35 + 0.65 * value_noise(UV * 9.0)) * critical * center_mask;
		float char_layer = wreck * (0.48 + 0.32 * value_noise(UV * 17.0));
		float dark_mask = clamp(max(max(impact_damage, front_soot), max(broad_soot * 0.6, char_layer)), 0.0, 0.86);
		float metal_mask = clamp(max(fine_scratches * 0.58, max(paint_chips * 0.38, wheel_scuffs * 0.5)), 0.0, 0.68);

		vec3 soot_color = mix(damage_tint.rgb, vec3(0.018, 0.016, 0.014), 0.62 + critical * 0.25);
		vec3 exposed_metal = vec3(0.56, 0.51, 0.43);
		vec3 overlay_color = mix(exposed_metal, soot_color, smoothstep(0.12, 0.62, dark_mask));
		float overlay_alpha = clamp(max(dark_mask, metal_mask), 0.0, 0.86) * base.a;
		COLOR = vec4(overlay_color, overlay_alpha);
	}
}
"""
	return shader
