extends PanelContainer
class_name TutorialCoach

var player: Vehicle
var mode: StringName = &"race"
var step := 0
var elapsed := 0.0
var started := false
var label: Label

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.04, 0.94)
	style.border_color = Color(0.92, 0.61, 0.2, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)

func setup(value: Vehicle, game_mode: StringName) -> void:
	player = value
	mode = game_mode
	if started or DisplayServer.get_name() == "headless": return
	started = true
	var state := PlayerProfile.career_state()
	if not AccessibilitySettings.tutorial_enabled or bool(state.tutorial_complete): return
	visible = true
	_show_step()

func _process(delta: float) -> void:
	if not visible: return
	elapsed += delta
	match step:
		0:
			if Input.is_action_pressed("accelerate"): _advance()
		1:
			if Input.is_action_pressed("steer_left") or Input.is_action_pressed("steer_right"): _advance()
		2:
			if elapsed > 8.0: _advance()
		3:
			if Input.is_action_pressed("fire") or elapsed > 15.0: _complete()

func _advance() -> void:
	step += 1
	_show_step()

func _show_step() -> void:
	match step:
		0: label.text = "W / ↑  — ГАЗ    ·    S / ↓  — ТОРМОЗ И ЗАДНИЙ ХОД"
		1: label.text = "A D / ← →  — РУЛЕНИЕ    ·    машина поворачивает только в движении"
		2: label.text = "Собирайте подсвеченные поставки: ремонт, ускорение, таран и оружие"
		3: label.text = ("SPACE  — ОГОНЬ    ·    уничтожьте всех противников" if mode == &"arena" else "SPACE  — ОГОНЬ    ·    R — перезапуск    ·    ESC — пауза")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		_complete()
		get_viewport().set_input_as_handled()

func _complete() -> void:
	visible = false
	var data := PlayerProfile.read()
	data.career.tutorial_complete = true
	PlayerProfile.save(data)
