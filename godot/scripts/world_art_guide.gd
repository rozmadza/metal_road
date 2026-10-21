extends RefCounted
class_name WorldArtGuide
## Runtime counterpart of docs/ART_GUIDE.md. All world rendering uses these
## values so new biomes do not invent a different visual language.

const SHADOW_OFFSET := Vector2(3.0, 4.0)
const SHADOW_COLOR := Color(0.018, 0.024, 0.028, 0.58)
const CONTACT_COLOR := Color(0.018, 0.026, 0.032, 0.68)
const ROAD_EDGE_DARK := Color(0.025, 0.029, 0.032, 0.98)
const WALL_DARK := Color(0.105, 0.11, 0.115, 1.0)
const WALL_METAL := Color(0.34, 0.35, 0.35, 1.0)
const ACCENT_WARM := Color(0.78, 0.48, 0.16, 1.0)


static func arena_surface_tint(biome_id: StringName, fallback: Color) -> Color:
	var palette := {
		&"scrapyard": Color(0.31, 0.285, 0.255, 1.0),
		&"flooded_depot": Color(0.255, 0.34, 0.36, 1.0),
		&"red_quarry": Color(0.43, 0.29, 0.19, 1.0),
		&"steel_foundry": Color(0.29, 0.315, 0.325, 1.0),
		&"rust_frontier": Color(0.39, 0.285, 0.19, 1.0),
	}
	return palette.get(biome_id, fallback.lightened(0.12))


static func surface_material(tint: Color, detail_strength: float = 0.34) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 surface_tint : source_color = vec4(0.36, 0.38, 0.39, 1.0);
uniform float detail_strength = 0.34;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luminance = dot(tex.rgb, vec3(0.2126, 0.7152, 0.0722));
	float detail = (luminance - 0.5) * detail_strength;
	vec3 colored = clamp(surface_tint.rgb + vec3(detail), vec3(0.14), vec3(0.62));
	float saturation = max(max(colored.r, colored.g), colored.b) - min(min(colored.r, colored.g), colored.b);
	colored = mix(colored, vec3(dot(colored, vec3(0.2126, 0.7152, 0.0722))), saturation * 0.14);
	COLOR = vec4(colored, tex.a * surface_tint.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("surface_tint", tint)
	material.set_shader_parameter("detail_strength", detail_strength)
	return material
