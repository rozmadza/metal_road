extends Control
class_name MainMenu
## Main menu screen: start a new race or adjust audio and video settings.

const InputBindingsService = preload("res://scripts/input_bindings.gd")
const Locale = preload("res://scripts/locale_manager.gd")

const PRE_RACE_SCENE := "res://scenes/PreRace.tscn"
const GARAGE_SCENE := "res://scenes/Garage.tscn"
const CAREER_SCENE := "res://scenes/Career.tscn"
const SURVIVAL_SCENE := "res://scenes/ArenaBattle.tscn"
const PROGRESS_SCENE := "res://scenes/Progress.tscn"
const CONTROLS_SCENE := "res://scenes/Controls.tscn"
const CREDITS_SCENE := "res://scenes/Credits.tscn"

@onready var _menu_box: Control = %MenuBox
@onready var _settings_panel: Control = %SettingsPanel
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _engine_slider: HSlider = %EngineSlider
@onready var _fullscreen_check: CheckBox = %FullscreenCheck

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_VERSION := 2
const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
static var settings_path_override := ""
const BUS_NAMES := [&"Master", &"Music", &"SFX", &"Engine", &"UI", &"Weapons", &"Impacts"]
var _settings := ConfigFile.new()
var _loading_settings := false


func _ready() -> void:
	%GarageButton.pressed.connect(_on_garage_pressed)
	%ProgressButton.pressed.connect(func(): SceneTransition.go(PROGRESS_SCENE, "ЗАГРУЗКА ПРОФИЛЯ"))
	%CreditsButton.pressed.connect(func(): SceneTransition.go(CREDITS_SCENE, "ЗАГРУЗКА ТИТРОВ"))
	%CareerButton.pressed.connect(_on_career_pressed)
	%RaceButton.pressed.connect(_on_race_pressed)
	%SurvivalButton.pressed.connect(_on_survival_pressed)
	%SettingsButton.pressed.connect(_on_settings_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	%BackButton.pressed.connect(_on_back_pressed)
	%ControlsButton.pressed.connect(func(): SceneTransition.go(CONTROLS_SCENE, "ЗАГРУЗКА УПРАВЛЕНИЯ"))
	_volume_slider.value_changed.connect(_on_volume_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_engine_slider.value_changed.connect(_on_engine_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	for label in ["1280 × 720", "1600 × 900", "1920 × 1080"]: %ResolutionOption.add_item(label)
	%ResolutionOption.item_selected.connect(_on_resolution_selected)
	%LanguageOption.add_item("РУССКИЙ", 0)
	%LanguageOption.add_item("ENGLISH", 1)
	%LanguageOption.item_selected.connect(_on_language_selected)
	%DifficultyOption.add_item("ПОМОЩЬ", 0)
	%DifficultyOption.add_item("СТАНДАРТ", 1)
	%DifficultyOption.add_item("ХАРДКОР", 2)
	%DifficultyOption.item_selected.connect(func(index: int): AccessibilitySettings.difficulty = index; _save_settings())
	%ShakeSlider.value_changed.connect(func(value: float): AccessibilitySettings.screen_shake = value; _save_settings())
	%ReducedFlashesCheck.toggled.connect(func(value: bool): AccessibilitySettings.reduced_flashes = value; _save_settings())
	%HighContrastCheck.toggled.connect(func(value: bool): AccessibilitySettings.high_contrast = value; _save_settings())
	%TutorialCheck.toggled.connect(func(value: bool): AccessibilitySettings.tutorial_enabled = value; _save_settings())
	_ensure_audio_buses()
	InputBindingsService.ensure_controller_defaults()
	InputBindingsService.load_custom_bindings()
	_load_settings()
	_apply_locale()
	_show_menu()
	# These are the two heaviest and most frequently opened branches. Warming
	# only them avoids turning the main menu itself into a burst of disk work.
	SceneTransition.warm([PRE_RACE_SCENE, GARAGE_SCENE])


func _show_menu() -> void:
	_menu_box.visible = true
	_settings_panel.visible = false
	%SettingsShade.visible = false
	%RaceButton.grab_focus()


func _on_race_pressed() -> void:
	CareerSession.clear_selection()
	PreRaceSetup.request_mode(&"race")
	SceneTransition.go(PRE_RACE_SCENE, "ПОДГОТОВКА ГОНКИ")


func _on_survival_pressed() -> void:
	CareerSession.clear_selection()
	PreRaceSetup.request_mode(&"survival")
	SceneTransition.go(PRE_RACE_SCENE, "ПОДГОТОВКА АРЕНЫ")


func _on_settings_pressed() -> void:
	_menu_box.visible = false
	_settings_panel.visible = true
	%SettingsShade.visible = true
	%BackButton.grab_focus()


func _on_back_pressed() -> void:
	_show_menu()


func _on_volume_changed(value: float) -> void:
	_set_bus_value(&"Master", value)
	_save_settings()


func _on_music_changed(value: float) -> void:
	_set_bus_value(&"Music", value)
	_save_settings()


func _on_sfx_changed(value: float) -> void:
	_set_bus_value(&"SFX", value)
	_set_bus_value(&"UI", value)
	_set_bus_value(&"Weapons", value)
	_set_bus_value(&"Impacts", value)
	_save_settings()


func _on_engine_changed(value: float) -> void:
	_set_bus_value(&"Engine", value)
	_save_settings()


func _on_fullscreen_toggled(enabled: bool) -> void:
	_apply_window_settings(enabled, %ResolutionOption.selected)
	_save_settings()


func _on_resolution_selected(index: int) -> void:
	_apply_window_settings(_fullscreen_check.button_pressed, index)
	_save_settings()


func _apply_window_settings(fullscreen: bool, resolution_index: int) -> void:
	var index := clampi(resolution_index, 0, WINDOW_SIZES.size() - 1)
	var target_size: Vector2i = WINDOW_SIZES[index]
	if fullscreen:
		# Borderless fullscreen always uses the desktop resolution, which made the
		# resolution selector appear to do nothing. Set the requested size while
		# windowed, then enter exclusive fullscreen so the display mode can follow it.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(target_size)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		return
	# Leave fullscreen before resizing; window_set_size is ignored by some
	# desktop backends while the window is still in fullscreen mode.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(target_size)
	var screen := DisplayServer.window_get_current_screen()
	var screen_position := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_position(screen_position + (screen_size - target_size) / 2)
	DisplayServer.window_set_min_size(Vector2i(960, 540))


func _on_language_selected(index: int) -> void:
	Locale.set_locale(Locale.EN if index == 1 else Locale.RU)
	_apply_locale()
	_save_settings()


func _on_quit_pressed() -> void:
	# Allow the mechanical click to sound before closing the application.
	%QuitButton.disabled = true
	await get_tree().create_timer(0.18).timeout
	get_tree().quit()


func _on_garage_pressed() -> void:
	SceneTransition.go(GARAGE_SCENE, "ОТКРЫВАЕМ ГАРАЖ")


func _on_career_pressed() -> void:
	var driver_id := StringName(PlayerProfile.career_state().get("driver_id", &""))
	SceneTransition.go(DriverRoster.SELECT_SCENE if DriverRoster.by_id(driver_id).is_empty() else CAREER_SCENE, "ЗАГРУЗКА КАРЬЕРЫ")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _settings_panel.visible:
		_show_menu()
		get_viewport().set_input_as_handled()


func _ensure_audio_buses() -> void:
	for bus_name in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	var sfx_index := AudioServer.get_bus_index(&"SFX")
	for child_name in [&"UI", &"Weapons", &"Impacts"]:
		var index := AudioServer.get_bus_index(child_name)
		if index >= 0 and sfx_index >= 0:
			AudioServer.set_bus_send(index, &"SFX")


func _set_bus_value(bus_name: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0: return
	AudioServer.set_bus_mute(index, value <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))


func _bus_value(bus_name: StringName) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	return db_to_linear(AudioServer.get_bus_volume_db(index)) if index >= 0 else 1.0


func _load_settings() -> void:
	_settings.load(_settings_path())
	var version := int(_settings.get_value("settings", "settings_version", SETTINGS_VERSION))
	# Keep version-1 audio/video values and add accessibility defaults in place.
	if version > SETTINGS_VERSION or version <= 0:
		_settings = ConfigFile.new()
	_loading_settings = true
	_volume_slider.value = float(_settings.get_value("settings", "master_volume", _bus_value(&"Master")))
	_music_slider.value = float(_settings.get_value("settings", "music_volume", _bus_value(&"Music")))
	_sfx_slider.value = float(_settings.get_value("settings", "sfx_volume", _bus_value(&"SFX")))
	_engine_slider.value = float(_settings.get_value("settings", "engine_volume", _bus_value(&"Engine")))
	_fullscreen_check.button_pressed = bool(_settings.get_value("settings", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN))
	var resolution_index := clampi(int(_settings.get_value("settings", "resolution_index", 0)), 0, 2)
	%ResolutionOption.select(resolution_index)
	Locale.set_locale(String(_settings.get_value("settings", "locale", Locale.RU)))
	%LanguageOption.select(1 if Locale.current == Locale.EN else 0)
	PlayerProfile.set_active_slot(clampi(int(_settings.get_value("settings", "profile_slot", 1)), 1, 3))
	AccessibilitySettings.load_settings(_settings)
	%DifficultyOption.select(AccessibilitySettings.difficulty)
	%ShakeSlider.value = AccessibilitySettings.screen_shake
	%ReducedFlashesCheck.button_pressed = AccessibilitySettings.reduced_flashes
	%HighContrastCheck.button_pressed = AccessibilitySettings.high_contrast
	%TutorialCheck.button_pressed = AccessibilitySettings.tutorial_enabled
	_loading_settings = false
	_set_bus_value(&"Master", _volume_slider.value)
	_set_bus_value(&"Music", _music_slider.value)
	_set_bus_value(&"SFX", _sfx_slider.value)
	_set_bus_value(&"UI", _sfx_slider.value)
	_set_bus_value(&"Weapons", _sfx_slider.value)
	_set_bus_value(&"Impacts", _sfx_slider.value)
	_set_bus_value(&"Engine", _engine_slider.value)
	_apply_window_settings(_fullscreen_check.button_pressed, resolution_index)
	_save_settings()


func _save_settings() -> void:
	if _loading_settings: return
	_settings.set_value("settings", "settings_version", SETTINGS_VERSION)
	_settings.set_value("settings", "master_volume", _volume_slider.value)
	_settings.set_value("settings", "music_volume", _music_slider.value)
	_settings.set_value("settings", "sfx_volume", _sfx_slider.value)
	_settings.set_value("settings", "engine_volume", _engine_slider.value)
	_settings.set_value("settings", "fullscreen", _fullscreen_check.button_pressed)
	_settings.set_value("settings", "resolution_index", %ResolutionOption.selected)
	_settings.set_value("settings", "locale", Locale.current)
	_settings.set_value("settings", "profile_slot", PlayerProfile.active_slot)
	_settings.set_value("accessibility", "difficulty", AccessibilitySettings.difficulty)
	_settings.set_value("accessibility", "screen_shake", AccessibilitySettings.screen_shake)
	_settings.set_value("accessibility", "reduced_flashes", AccessibilitySettings.reduced_flashes)
	_settings.set_value("accessibility", "high_contrast", AccessibilitySettings.high_contrast)
	_settings.set_value("accessibility", "tutorial_enabled", AccessibilitySettings.tutorial_enabled)
	_settings.save(_settings_path())

func _settings_path() -> String:
	return settings_path_override if not settings_path_override.is_empty() else SETTINGS_PATH


func _apply_locale() -> void:
	%RaceButton.text = Locale.tr_key("race")
	%CareerButton.text = Locale.tr_key("career")
	%SurvivalButton.text = Locale.tr_key("survival")
	%GarageButton.text = Locale.tr_key("garage")
	%ProgressButton.text = Locale.tr_key("progress")
	%SettingsButton.text = Locale.tr_key("settings")
	%QuitButton.text = Locale.tr_key("quit")
	$SettingsPanel/Panel/Margin/VBox/SettingsTitle.text = Locale.tr_key("settings")
	$SettingsPanel/Panel/Margin/VBox/VolumeRow/VolumeLabel.text = Locale.tr_key("master")
	$SettingsPanel/Panel/Margin/VBox/MusicRow/MusicLabel.text = Locale.tr_key("music")
	$SettingsPanel/Panel/Margin/VBox/SfxRow/SfxLabel.text = Locale.tr_key("effects")
	$SettingsPanel/Panel/Margin/VBox/EngineRow/EngineLabel.text = Locale.tr_key("engine")
	%FullscreenCheck.text = Locale.tr_key("fullscreen")
	$SettingsPanel/Panel/Margin/VBox/DifficultyRow/Label.text = Locale.tr_key("difficulty")
	$SettingsPanel/Panel/Margin/VBox/ShakeRow/Label.text = Locale.tr_key("shake")
	$SettingsPanel/Panel/Margin/VBox/ResolutionRow/Label.text = Locale.tr_key("resolution")
	$SettingsPanel/Panel/Margin/VBox/LanguageRow/Label.text = Locale.tr_key("language")
	%ControlsButton.text = Locale.tr_key("controls")
	%ReducedFlashesCheck.text = Locale.tr_key("flashes")
	%HighContrastCheck.text = Locale.tr_key("contrast")
	%TutorialCheck.text = Locale.tr_key("tutorial")
	%BackButton.text = Locale.tr_key("back")
