extends RefCounted
class_name InputBindings

const ACTIONS := [&"accelerate", &"brake", &"steer_left", &"steer_right", &"fire", &"restart", &"interact"]
const LABELS := {
	&"accelerate": "ГАЗ / ACCELERATE", &"brake": "ТОРМОЗ / BRAKE",
	&"steer_left": "ВЛЕВО / LEFT", &"steer_right": "ВПРАВО / RIGHT",
	&"fire": "ОГОНЬ / FIRE", &"restart": "РЕСТАРТ / RESTART",
	&"interact": "ЗАМЕНИТЬ ОРУЖИЕ / INTERACT",
}
const SETTINGS_PATH := "user://settings.cfg"

static func ensure_controller_defaults() -> void:
	if not InputMap.has_action(&"interact"):
		InputMap.add_action(&"interact")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		InputMap.action_add_event(&"interact", key)
	_add_button(&"interact", JOY_BUTTON_X)
	InputMap.action_set_deadzone(&"accelerate", 0.12)
	InputMap.action_set_deadzone(&"brake", 0.12)
	InputMap.action_set_deadzone(&"steer_left", 0.18)
	InputMap.action_set_deadzone(&"steer_right", 0.18)
	_add_axis(&"accelerate", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_axis(&"brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_axis(&"steer_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis(&"steer_right", JOY_AXIS_LEFT_X, 1.0)
	_add_button(&"steer_left", JOY_BUTTON_DPAD_LEFT)
	_add_button(&"steer_right", JOY_BUTTON_DPAD_RIGHT)
	_add_button(&"fire", JOY_BUTTON_A)
	_add_button(&"restart", JOY_BUTTON_Y)
	# Project-defined UI actions do not inherit Godot's editor defaults in an
	# exported build. Install a complete Xbox-style navigation layout at runtime.
	_add_button(&"ui_accept", JOY_BUTTON_A)
	_add_button(&"ui_cancel", JOY_BUTTON_B)
	_add_button(&"ui_cancel", JOY_BUTTON_START)
	_add_button(&"ui_up", JOY_BUTTON_DPAD_UP)
	_add_button(&"ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_button(&"ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_button(&"ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_axis(&"ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis(&"ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_axis(&"ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis(&"ui_right", JOY_AXIS_LEFT_X, 1.0)

static func display_for(action: StringName) -> String:
	var labels: Array[String] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			labels.append(event.as_text_physical_keycode())
		elif event is InputEventJoypadButton:
			labels.append("PAD %s" % _button_name(event.button_index))
		elif event is InputEventJoypadMotion:
			labels.append("PAD %s" % _axis_name(event.axis, event.axis_value))
	return " / ".join(labels)


static func interaction_key_label(joypad: bool, device: int = 0, controller_name: String = "") -> String:
	var name := controller_name if not controller_name.is_empty() else Input.get_joy_name(device)
	for event in InputMap.action_get_events(&"interact"):
		if joypad and event is InputEventJoypadButton:
			if name.is_empty() and event.button_index == JOY_BUTTON_X: return "X / □"
			var playstation := "playstation" in name.to_lower() or "dualshock" in name.to_lower() or "dualsense" in name.to_lower() or "ps4" in name.to_lower() or "ps5" in name.to_lower() or "sony" in name.to_lower() or name.to_lower() == "wireless controller"
			return "□" if playstation and event.button_index == JOY_BUTTON_X else _button_name(event.button_index)
		if not joypad and event is InputEventKey:
			return event.as_text_physical_keycode()
	return "X / □" if joypad else "E"

static func rebind_keyboard(action: StringName, event: InputEventKey) -> void:
	for old in InputMap.action_get_events(action):
		if old is InputEventKey:
			InputMap.action_erase_event(action, old)
	event.physical_keycode = event.physical_keycode if event.physical_keycode else event.keycode
	InputMap.action_add_event(action, event)

static func load_custom_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK: return
	for action in ACTIONS:
		var code := int(cfg.get_value("controls", String(action), 0))
		if code <= 0: continue
		var event := InputEventKey.new()
		event.physical_keycode = code as Key
		rebind_keyboard(action, event)

static func save_custom_bindings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	for action in ACTIONS:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				cfg.set_value("controls", String(action), event.physical_keycode if event.physical_keycode else event.keycode)
				break
	cfg.save(SETTINGS_PATH)

static func _add_button(action: StringName, button: JoyButton) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button: return
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

static func _add_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis == axis and signf(event.axis_value) == signf(value): return
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)

static func _button_name(button: int) -> String:
	return {JOY_BUTTON_A:"A", JOY_BUTTON_B:"B", JOY_BUTTON_X:"X", JOY_BUTTON_Y:"Y"}.get(button, str(button))

static func _axis_name(axis: int, value: float) -> String:
	if axis == JOY_AXIS_LEFT_X: return "L-STICK ←" if value < 0 else "L-STICK →"
	if axis == JOY_AXIS_TRIGGER_LEFT: return "LT"
	if axis == JOY_AXIS_TRIGGER_RIGHT: return "RT"
	return "AXIS %d" % axis
