extends RigidBody2D
## Isolated experiment only. Never instantiated by production Arena/Survival.
## Group shape matches ArenaNavigation's existing prop contract.
@export var size := Vector2(140,120)
@export var wreck_mass := 5000.0
@export var resistance := 5.0
var destroyed := false

func _ready() -> void:
	mass=wreck_mass
	gravity_scale=0
	linear_damp=resistance
	angular_damp=7.0
	continuous_cd=RigidBody2D.CCD_MODE_CAST_SHAPE
	var material:=PhysicsMaterial.new();material.friction=0.8;material.bounce=0
	physics_material_override=material
	add_to_group("arena_obstacles")
