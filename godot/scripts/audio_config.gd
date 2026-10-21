extends Resource
class_name AudioConfig
## Audio slots for the game. Assign streams in the Inspector to replace
## sounds or music without touching any code.

@export_group("Music")
@export var music: AudioStream
@export_range(-80.0, 24.0, 0.5) var music_volume_db: float = -14.0

@export_group("Vehicle")
@export var engine: AudioStream
@export var fire: AudioStream
@export var collision: AudioStream

@export_group("Race")
@export var finish: AudioStream

@export_group("Levels")
@export_range(-80.0, 24.0, 0.5) var sfx_volume_db: float = -8.0
@export_range(-80.0, 24.0, 0.5) var engine_volume_db: float = -16.0

@export_range(0.01, 1.0) var impact_cooldown: float = 0.08

@export_group("UI")
@export var menu_hover: AudioStream
@export var menu_click: AudioStream
@export_range(-60.0, 0.0) var ui_volume_db: float = -12.0

@export var explosion: AudioStream
