extends Control
class_name PauseOverlay

signal restart_requested
signal menu_requested

var _first_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.015, 0.02, 0.78)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "WASD / СТИК — ДВИЖЕНИЕ    SPACE / A — ОГОНЬ"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.7, 0.75, 0.76)
	box.add_child(hint)
	_add_button(box, "ПРОДОЛЖИТЬ", resume)
	_add_button(box, "НАЧАТЬ ЗАНОВО", _restart)
	_add_button(box, "В ГЛАВНОЕ МЕНЮ", _menu)

func _add_button(parent: Control, text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 46)
	button.theme_type_variation = &"IndustrialButton"
	button.pressed.connect(callback)
	parent.add_child(button)
	if _first_button == null:
		_first_button = button

func toggle() -> void:
	if visible: resume()
	else:
		visible = true
		get_tree().paused = true
		if is_instance_valid(_first_button):
			_first_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		resume()
		get_viewport().set_input_as_handled()

func resume() -> void:
	visible = false
	get_tree().paused = false

func _restart() -> void:
	resume()
	restart_requested.emit()

func _menu() -> void:
	resume()
	menu_requested.emit()
