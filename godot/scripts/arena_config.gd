extends Resource
class_name ArenaConfig
## Tunable data for a survival arena: size, obstacles and looks.
##
## Everything here can be edited in the Inspector (or a new `.tres`) without
## touching any game logic, exactly like [TrackConfig].

@export_group("Layout")
## Interior size of the arena (walls sit just outside this rectangle).
@export var size: Vector2 = Vector2(1000.0, 800.0)
@export_range(4.0, 100.0, 1.0) var wall_thickness: float = 20.0
## Obstacle rectangles in arena-local coordinates (0, 0 = top-left corner).
@export var obstacles: Array[Rect2] = []
@export var oil_spots: Array[Vector2] = []
@export var explosive_barrels: Array[Vector2] = []
@export var crates: Array[Vector2] = []
@export var tire_walls: Array[Vector2] = []
@export var wrecks: Array[Vector2] = []
@export var concrete_blocks: Array[Vector2] = []
@export var metal_fences: Array[Vector2] = []
## Spawn anchors are inset from the walls by this distance.
@export_range(0.0, 300.0, 5.0) var spawn_margin: float = 80.0

@export_group("Looks")
@export var floor_color: Color = Color(0.11, 0.12, 0.15)
@export var grid_color: Color = Color(0.17, 0.18, 0.22)
@export var wall_color: Color = Color(0.34, 0.36, 0.42)
@export var obstacle_color: Color = Color(0.26, 0.28, 0.33)
@export var obstacle_edge_color: Color = Color(0.44, 0.46, 0.54)
@export var floor_texture: Texture2D
@export var biome_id: StringName = &"scrapyard"
@export var biome_name: String = "SCRAPYARD ARENA"
@export_multiline var biome_description: String = "Свалка с плотными укрытиями."
@export var weather_type: StringName = &"clear"
@export_range(0.0, 1.0, 0.05) var storm_strength: float = 0.0
@export_range(0.5, 1.0, 0.01) var storm_traction: float = 0.84
@export var frontier_atlas: Texture2D

@export_group("Dynamic mechanic")
@export var mechanic_id: StringName = &""
@export var mechanic_label: String = ""
@export_range(5.0, 40.0, 0.5) var hazard_interval: float = 14.0

@export_group("Obstacle Art")
@export var school_bus_texture: Texture2D
@export var semi_truck_texture: Texture2D
@export var tire_heap_texture: Texture2D
@export var crushed_cars_texture: Texture2D
@export var crushed_container_texture: Texture2D
