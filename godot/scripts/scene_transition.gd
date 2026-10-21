extends CanvasLayer
class_name SceneTransition
## Non-blocking scene changes with a quiet, motion-free loading overlay.

var _overlay: ColorRect
var _label: Label
var _progress: ProgressBar
var _pending_path := ""
var _loading := false
var _ready_to_poll := false
var _warm_queue: Array[String] = []
var _warming_path := ""
var _cache: Dictionary = {}


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	set_process(true)


static func go(path: String, message: String = "") -> void:
	var service := _service()
	if service != null:
		service._go(path, message)


static func warm(paths: Array[String]) -> void:
	# Automated headless checks exit as soon as their assertions finish; leaving
	# worker loads alive during shutdown creates misleading truncated-resource
	# errors. Prewarming is only useful in an interactive build.
	if DisplayServer.get_name() == "headless":
		return
	var service := _service()
	if service != null:
		service._warm(paths)


static func is_busy() -> bool:
	var service := _service()
	return service != null and service._loading


static func _service() -> SceneTransition:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("Transition") as SceneTransition


func _go(path: String, message: String = "") -> void:
	if path.is_empty() or _loading:
		return
	# Navigation is a global UI action. Never let a gameplay pause leave the
	# loading layer responsive while the destination scene itself stays frozen.
	get_tree().paused = false
	_loading = true
	_ready_to_poll = false
	_pending_path = path
	_label.text = message if not message.is_empty() else "ПОДГОТОВКА МАРШРУТА"
	_progress.value = 4.0
	_overlay.visible = true
	# A deferred call still runs before the frame is drawn. Cached scenes can be
	# expensive to instantiate, so explicitly wait until the loading layer has
	# reached the screen before doing any scene work.
	_show_overlay_then_begin()


func _show_overlay_then_begin() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
	if _loading and not _pending_path.is_empty():
		_begin_transition()


func _warm(paths: Array[String]) -> void:
	for path in paths:
		if path.is_empty() or _cache.has(path) or path == _warming_path or path in _warm_queue:
			continue
		_warm_queue.append(path)
	_start_next_warm.call_deferred()


func _begin_transition() -> void:
	if _cache.has(_pending_path):
		_commit_scene(_cache[_pending_path] as PackedScene)
		return
	# A background warm-up may already own this request; the process loop will
	# promote it to the foreground without restarting the load.
	if _warming_path == _pending_path:
		_ready_to_poll = true
		return
	var error := ResourceLoader.load_threaded_request(_pending_path, "PackedScene", true)
	if error != OK and error != ERR_BUSY:
		push_error("Could not start scene load: %s" % _pending_path)
		_loading = false
		_ready_to_poll = false
		_overlay.visible = false
	else:
		_ready_to_poll = true


func _process(_delta: float) -> void:
	if _loading and _ready_to_poll:
		_update_foreground_load()
	elif not _warming_path.is_empty():
		_update_warm_load()
	elif not _warm_queue.is_empty():
		_start_next_warm()


func _update_foreground_load() -> void:
	if _pending_path.is_empty():
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_pending_path, progress)
	if not progress.is_empty():
		_progress.value = lerpf(8.0, 94.0, clampf(float(progress[0]), 0.0, 1.0))
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed := ResourceLoader.load_threaded_get(_pending_path) as PackedScene
		if packed != null:
			_cache[_pending_path] = packed
			_warming_path = "" if _warming_path == _pending_path else _warming_path
			_commit_scene(packed)
		else:
			_fail_transition()
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_fail_transition()


func _commit_scene(packed: PackedScene) -> void:
	_progress.value = 100.0
	var error := get_tree().change_scene_to_packed(packed)
	_pending_path = ""
	_loading = false
	_ready_to_poll = false
	_overlay.visible = false
	if error != OK:
		push_error("Could not switch to loaded scene")
	_start_next_warm.call_deferred()


func _fail_transition() -> void:
	push_error("Scene load failed: %s" % _pending_path)
	_pending_path = ""
	_loading = false
	_ready_to_poll = false
	_overlay.visible = false


func _start_next_warm() -> void:
	if _loading or not _warming_path.is_empty() or _warm_queue.is_empty():
		return
	_warming_path = _warm_queue.pop_front()
	var error := ResourceLoader.load_threaded_request(_warming_path, "PackedScene", true)
	if error != OK and error != ERR_BUSY:
		_warming_path = ""
		_start_next_warm.call_deferred()


func _update_warm_load() -> void:
	var status := ResourceLoader.load_threaded_get_status(_warming_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed := ResourceLoader.load_threaded_get(_warming_path) as PackedScene
		if packed != null:
			_cache[_warming_path] = packed
		_warming_path = ""
		_start_next_warm.call_deferred()
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_warming_path = ""
		_start_next_warm.call_deferred()


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "LoadingOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.018, 0.024, 0.028, 0.96)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420.0, 126.0)
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#10171b")
	style.border_color = Color("#c58a32")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", style)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)
	_label = Label.new()
	_label.text = "ПОДГОТОВКА МАРШРУТА"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color("#e8dfcf"))
	layout.add_child(_label)
	var hint := Label.new()
	hint.text = "ЗАГРУЗКА РЕСУРСОВ"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("#849196"))
	layout.add_child(hint)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(360.0, 8.0)
	_progress.show_percentage = false
	layout.add_child(_progress)
	_overlay.visible = false
