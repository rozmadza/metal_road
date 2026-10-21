extends Control
class_name DriverSelect

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const CAREER_SCENE := "res://scenes/Career.tscn"

var selected_index := 0
var _buttons: Array[Button] = []


func _ready() -> void:
	%BackButton.pressed.connect(func(): SceneTransition.go(MENU_SCENE, "ВОЗВРАЩЕНИЕ В МЕНЮ"))
	%ConfirmButton.pressed.connect(_confirm)
	for index in DriverRoster.DRIVERS.size():
		var driver: Dictionary = DriverRoster.DRIVERS[index]
		var button := Button.new()
		button.name = "Driver_%s" % driver.id
		button.custom_minimum_size = Vector2(0, 72)
		button.theme_type_variation = &"IndustrialButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s\n%s" % [driver.name, driver.callsign]
		button.pressed.connect(_select.bind(index))
		%DriverList.add_child(button)
		_buttons.append(button)
	var saved_id := StringName(PlayerProfile.career_state().get("driver_id", &""))
	for index in DriverRoster.DRIVERS.size():
		if DriverRoster.DRIVERS[index].id == saved_id:
			selected_index = index
	_refresh()


func _select(index: int) -> void:
	selected_index = index
	_refresh()


func _refresh() -> void:
	var driver: Dictionary = DriverRoster.DRIVERS[selected_index]
	for index in _buttons.size():
		_buttons[index].button_pressed = index == selected_index
	%Portrait.texture = load(driver.portrait)
	%DriverName.text = driver.name
	%Callsign.text = driver.callsign
	%Biography.text = driver.bio
	%Passive.text = driver.passive


func _confirm() -> void:
	var data := PlayerProfile.read()
	data.career.driver_id = DriverRoster.DRIVERS[selected_index].id
	PlayerProfile.save(data)
	SceneTransition.go(CAREER_SCENE, "ЗАГРУЗКА КАРЬЕРЫ")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneTransition.go(MENU_SCENE, "ВОЗВРАЩЕНИЕ В МЕНЮ")
