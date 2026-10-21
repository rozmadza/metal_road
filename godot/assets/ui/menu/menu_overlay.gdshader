shader_type canvas_item;
render_mode unshaded;

uniform float darkening : hint_range(0.0, 1.0) = 0.12;
uniform float left_shade : hint_range(0.0, 1.0) = 0.8;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float left = (1.0 - smoothstep(0.12, 0.65, UV.x)) * left_shade;
	float edge = smoothstep(0.22, 0.72, distance(UV, vec2(0.5))) * vignette;
	float bottom = smoothstep(0.72, 1.0, UV.y) * 0.35;
	COLOR = vec4(0.015, 0.025, 0.035, clamp(darkening + left + edge + bottom, 0.0, 0.95));
}
