extends Node
## Scene-local UI audio. A short click owns its lifetime across scene changes.

@export var config: AudioConfig
var _hover: AudioStreamPlayer
var _last_hover_ms: int = -1000

func _ready() -> void:
	_hover = AudioStreamPlayer.new()
	_hover.bus = &"UI"
	add_child(_hover)
	wire(get_parent())

func wire(node: Node) -> void:
	if node is BaseButton:
		node.mouse_entered.connect(play_hover)
		node.focus_entered.connect(play_hover)
		node.pressed.connect(play_click)
	for child in node.get_children():
		if child != self:
			wire(child)

func play_hover() -> void:
	if config == null or config.menu_hover == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_hover_ms < 70:
		return
	_last_hover_ms = now
	_hover.stream = config.menu_hover
	_hover.volume_db = config.ui_volume_db
	_hover.play()

func play_click() -> void:
	if config == null or config.menu_click == null:
		return
	var player := AudioStreamPlayer.new()
	player.name = "UIClick"
	player.bus = &"UI"
	player.stream = config.menu_click
	player.volume_db = config.ui_volume_db
	get_tree().root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	# Also clean up on headless/dummy audio backends.
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(0.2, config.menu_click.get_length() + 0.1)
	player.add_child(timer)
	timer.timeout.connect(player.queue_free)
	timer.start()
