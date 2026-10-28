extends RefCounted
## Timing sink used only by the disposable instrumented project copy.
static var enabled := false
static var phase := "setup"
static var next_id := 0
static var events: Array[Dictionary] = []

static func begin(kind: int, armed: bool) -> int:
	if not enabled:
		return -1
	next_id += 1
	events.append({"id": next_id, "phase": phase, "stage": "begin", "kind_request": kind, "armed": armed, "at_us": Time.get_ticks_usec()})
	return next_id

static func record(stage: String, usec: int, id: int = -1, detail: String = "") -> void:
	if not enabled:
		return
	events.append({"id": id, "phase": phase, "stage": stage, "us": usec, "detail": detail, "at_us": Time.get_ticks_usec(), "physics_frame": Engine.get_physics_frames()})
