extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("MENU VISUAL FAIL: ", label)

func run() -> void:
	var menu: MainMenu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(menu.get_node("%Logo").texture != null, "logo assigned")
	check(menu.get_node("Background/Artwork").texture != null, "background assigned")
	check(menu.get_node("Background/Shade").material != null, "gradient/vignette assigned")
	for name in ["Race", "Survival", "Garage", "Settings", "Quit"]:
		var button: Button = menu.get_node("%" + name + "Button")
		check(button.visible and not button.disabled, "available " + name)
		check(button.theme_type_variation == &"IndustrialButton", "shared style " + name)
		check(button.pressed.get_connections().size() >= 2, "action and click wired " + name)
		check(button.mouse_entered.get_connections().size() > 0, "hover wired " + name)
	var race: Button = menu.get_node("%RaceButton")
	check(race.get_theme_stylebox("normal") != race.get_theme_stylebox("hover"), "distinct hover")
	check(race.get_theme_stylebox("hover") != race.get_theme_stylebox("pressed"), "distinct pressed")
	check(race.has_focus(), "keyboard focus")
	menu.get_node("%SettingsButton").pressed.emit()
	check(menu.get_node("%SettingsShade").visible and menu.get_node("%BackButton").has_focus(), "settings modal focus")
	menu.get_node("%BackButton").pressed.emit()
	check(not menu.get_node("%SettingsShade").visible and race.has_focus(), "back restores focus")
	var sound := menu.get_node("UISounds")
	sound._last_hover_ms = -1000
	sound.play_hover()
	check(sound._hover.stream == sound.config.menu_hover and sound._hover.bus == &"UI", "hover stream/bus")
	sound.play_click()
	var clicks := 0
	for child in root.get_children():
		if child is AudioStreamPlayer:
			clicks += 1
			check(child.stream == sound.config.menu_click and child.bus == &"UI", "click survives scene ownership")
	check(clicks > 0, "click created")
	sound.config = null
	sound.play_click()
	sound.play_hover()
	menu.free()
	await create_timer(0.4).timeout
	for child in root.get_children():
		check(not child is AudioStreamPlayer, "click cleaned up")
	print("MENU VISUAL: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
