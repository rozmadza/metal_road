extends Control

func _ready() -> void:
	%BackButton.pressed.connect(func(): SceneTransition.go("res://scenes/MainMenu.tscn", "ВОЗВРАЩЕНИЕ В МЕНЮ"))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneTransition.go("res://scenes/MainMenu.tscn", "ВОЗВРАЩЕНИЕ В МЕНЮ")
