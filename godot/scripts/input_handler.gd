extends RefCounted
class_name InputHandler
## Translates Godot input actions into the shared vehicle command contract:
## `{ throttle, brake, steer, fire, restart }`.
##
## The key bindings themselves live in Project Settings -> Input Map, so they
## can be rebound in the editor. This class only contains the mapping logic
## (conflict resolution etc.) shared with the Python prototype.

const ACTION_ACCELERATE := "accelerate"
const ACTION_BRAKE := "brake"
const ACTION_STEER_LEFT := "steer_left"
const ACTION_STEER_RIGHT := "steer_right"
const ACTION_FIRE := "fire"
const ACTION_RESTART := "restart"
const ACTION_TOGGLE_DEBUG := "toggle_debug"


func get_commands() -> Dictionary:
	# Action strengths preserve analogue trigger and stick travel while keyboard
	# keys still naturally report 0 or 1.
	var throttle := Input.get_action_strength(ACTION_ACCELERATE)
	var brake := Input.get_action_strength(ACTION_BRAKE)
	var steer := Input.get_action_strength(ACTION_STEER_RIGHT) - Input.get_action_strength(ACTION_STEER_LEFT)
	# W + S cancels out.
	if throttle > 0.0 and brake > 0.0:
		throttle = 0.0
		brake = 0.0

	return {
		"throttle": throttle,
		"brake": brake,
		"steer": steer,
		"fire": Input.is_action_pressed(ACTION_FIRE),
		"restart": Input.is_action_just_pressed(ACTION_RESTART),
	}


func is_debug_toggle_pressed() -> bool:
	return Input.is_action_just_pressed(ACTION_TOGGLE_DEBUG)
