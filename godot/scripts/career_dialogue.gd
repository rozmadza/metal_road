extends Control

var _lines: Array = []
var _line_index := 0
var _driver: Dictionary = {}
var _rival: Dictionary = {}
var _speaker: Label
var _speech: Label
var _continue: Button
var _driver_portrait: TextureRect
var _rival_portrait: TextureRect
var _driver_name: Label
var _rival_name: Label
var _driver_frame: PanelContainer
var _rival_frame: PanelContainer


func _ready() -> void:
	if CareerStory.pending.is_empty():
		SceneTransition.go(CareerSession.CAREER_SCENE, "КАРЬЕРА")
		return
	_driver = CareerStory.pending.get("driver", {})
	_rival = CareerStory.pending.get("rival", {})
	_lines = CareerStory.pending.get("lines", [])
	_build_ui()
	_show_line()
	_continue.grab_focus()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("0b1015")
	add_child(background)
	var glow := ColorRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(0.08, 0.12, 0.14, 0.25)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var chapter := _label(String(CareerStory.pending.get("chapter", "КАРЬЕРА")), 27, Color("f5c26b"))
	layout.add_child(chapter)
	layout.add_child(_label(String(CareerStory.pending.get("detail", "")), 15, Color("b9c9cc")))
	var cast := HBoxContainer.new()
	cast.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cast.add_theme_constant_override("separation", 18)
	layout.add_child(cast)
	_driver_frame = _portrait_card(cast, _driver, Color("34b4bb"), true)
	_rival_frame = _portrait_card(cast, _rival, Color("e85c4a"), false)
	var dialogue := PanelContainer.new()
	dialogue.add_theme_stylebox_override("panel", _panel_style(Color("111920"), Color("cf9751"), 2))
	dialogue.custom_minimum_size.y = 145
	layout.add_child(dialogue)
	var inset := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 16)
	dialogue.add_child(inset)
	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 10)
	inset.add_child(text_column)
	_speaker = _label("", 18, Color("f5c26b"))
	text_column.add_child(_speaker)
	_speech = _label("", 20, Color("f0f3f0"))
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_column.add_child(_speech)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	layout.add_child(actions)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var back := Button.new()
	back.text = "НАЗАД" if String(CareerStory.pending.get("chapter", "")).contains("ПЕРЕД") else "К КАРЬЕРЕ"
	back.custom_minimum_size = Vector2(135, 42)
	back.pressed.connect(_back)
	actions.add_child(back)
	var skip := Button.new()
	skip.text = "ПРОПУСТИТЬ"
	skip.custom_minimum_size = Vector2(145, 42)
	skip.pressed.connect(_finish)
	actions.add_child(skip)
	_continue = Button.new()
	_continue.text = "ДАЛЕЕ"
	_continue.custom_minimum_size = Vector2(175, 42)
	_continue.pressed.connect(_next)
	actions.add_child(_continue)


func _portrait_card(parent: HBoxContainer, profile: Dictionary, color: Color, is_driver: bool) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _panel_style(Color("162029"), color.darkened(0.65), 2))
	parent.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	frame.add_child(column)
	var portrait := TextureRect.new()
	portrait.texture = load(String(profile.get("portrait", ""))) as Texture2D
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Source portraits are square; fitting them preserves the full face and hair
	# on both 16:9 and smaller displays instead of cropping the top edge.
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.custom_minimum_size.y = 100
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait)
	var name_label := _label(String(profile.get("name", "")), 18, color)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	if is_driver:
		_driver_portrait = portrait
		_driver_name = name_label
	else:
		_rival_portrait = portrait
		_rival_name = name_label
	return frame


func _panel_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	return style


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _show_line() -> void:
	if _lines.is_empty():
		_finish()
		return
	var line: Dictionary = _lines[_line_index]
	var player_speaks: bool = StringName(line.get("speaker", &"")) == StringName(_driver.get("id", &""))
	_speaker.text = String(_driver.get("name", "")) if player_speaks else String(_rival.get("name", ""))
	_speech.text = String(line.get("text", ""))
	_driver_portrait.modulate = Color.WHITE if player_speaks else Color(0.42, 0.47, 0.5)
	_rival_portrait.modulate = Color(0.42, 0.47, 0.5) if player_speaks else Color.WHITE
	_continue.text = "В ГОНКУ" if _line_index == _lines.size() - 1 and String(CareerStory.pending.get("chapter", "")).contains("ПЕРЕД") else ("В КАРЬЕРУ" if _line_index == _lines.size() - 1 else "ДАЛЕЕ")


func _next() -> void:
	_line_index += 1
	if _line_index >= _lines.size():
		_finish()
	else:
		_show_line()


func _finish() -> void:
	var destination := String(CareerStory.pending.get("destination", CareerSession.CAREER_SCENE))
	CareerStory.clear()
	SceneTransition.go(destination, "ВЫЕЗД НА СТАРТ" if destination == "res://scenes/Main.tscn" else "КАРЬЕРА")


func _back() -> void:
	var destination := String(CareerStory.pending.get("back", CareerSession.CAREER_SCENE))
	CareerStory.clear()
	SceneTransition.go(destination, "ВОЗВРАЩЕНИЕ")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
