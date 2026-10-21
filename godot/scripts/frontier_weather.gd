extends CanvasLayer
class_name FrontierWeather

signal storm_changed(active: bool)

var strength := 0.7
var interval := 30.0
var duration := 12.0
var traction := 0.82
var intensity := 0.0
var storm_active := false
var _clock := 8.0
var _overlay: ColorRect
var _label: Label

func setup(storm_strength: float, storm_interval: float, storm_duration: float, storm_traction: float) -> void:
	strength = storm_strength
	interval = storm_interval
	duration = storm_duration
	traction = storm_traction

func _ready() -> void:
	layer = 2
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity = 0.0;
uniform float time_shift = 0.0;
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void fragment(){
 vec2 p = SCREEN_UV * vec2(46.0, 28.0) + vec2(time_shift * 2.8, time_shift * 0.35);
 float n = hash(floor(p)) * 0.55 + hash(floor(p * 0.43)) * 0.45;
 float bands = smoothstep(0.25, 0.9, sin((SCREEN_UV.x + SCREEN_UV.y * 0.32 + time_shift) * 26.0) * 0.5 + 0.5);
 float alpha = intensity * (0.10 + n * 0.15 + bands * 0.08);
 COLOR = vec4(0.62, 0.34, 0.12, alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_overlay.material = material
	add_child(_overlay)
	_label = Label.new()
	_label.text = "ПЫЛЕВАЯ БУРЯ"
	_label.position = Vector2(24, 92)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color("f1b45d"))
	_label.visible = false
	add_child(_label)

func _process(delta: float) -> void:
	_clock -= delta
	if _clock <= 0.0:
		storm_active = not storm_active
		_clock = duration if storm_active else interval
		_label.visible = storm_active
		storm_changed.emit(storm_active)
	var target := strength if storm_active else 0.0
	intensity = move_toward(intensity, target, delta * 0.28)
	if _overlay != null:
		_overlay.material.set_shader_parameter("intensity", intensity)
		_overlay.material.set_shader_parameter("time_shift", Time.get_ticks_msec() / 1000.0)

func grip_multiplier() -> float:
	return lerpf(1.0, traction, intensity)

func force_storm(active: bool) -> void:
	storm_active = active
	_clock = duration if active else interval
	intensity = strength if active else 0.0
	if _label != null: _label.visible = active
	storm_changed.emit(active)
