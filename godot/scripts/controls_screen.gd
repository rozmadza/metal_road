extends Control

const Bindings = preload("res://scripts/input_bindings.gd")
const Locale = preload("res://scripts/locale_manager.gd")

const MENU := "res://scenes/MainMenu.tscn"
var waiting_for: StringName = &""
var buttons := {}

func _ready() -> void:
	Bindings.ensure_controller_defaults()
	Bindings.load_custom_bindings()
	for action in Bindings.ACTIONS:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(620, 48)
		var label := Label.new()
		label.text = Bindings.LABELS[action]
		label.custom_minimum_size = Vector2(245, 0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var button := Button.new()
		button.custom_minimum_size = Vector2(360, 42)
		button.theme_type_variation = &"IndustrialButton"
		button.pressed.connect(_begin_rebind.bind(action))
		row.add_child(label)
		row.add_child(button)
		%Rows.add_child(row)
		buttons[action] = button
	%BackButton.pressed.connect(func(): SceneTransition.go(MENU, "ВОЗВРАЩЕНИЕ В МЕНЮ"))
	_refresh()

func _begin_rebind(action: StringName) -> void:
	waiting_for = action
	%Prompt.text = "НАЖМИТЕ НОВУЮ КЛАВИШУ · ESC — ОТМЕНА" if Locale.current == Locale.RU else "PRESS A NEW KEY · ESC TO CANCEL"
	buttons[action].text = "…"

func _input(event: InputEvent) -> void:
	if waiting_for == &"": return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode != KEY_ESCAPE:
			Bindings.rebind_keyboard(waiting_for, event)
			Bindings.save_custom_bindings()
		waiting_for = &""
		%Prompt.text = "КЛАВИАТУРА И ГЕЙМПАД ГОТОВЫ" if Locale.current == Locale.RU else "KEYBOARD AND GAMEPAD READY"
		_refresh()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	for action in buttons:
		buttons[action].text = Bindings.display_for(action)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if waiting_for != &"":
			waiting_for = &""
			_refresh()
		else:
			SceneTransition.go(MENU, "ВОЗВРАЩЕНИЕ В МЕНЮ")
