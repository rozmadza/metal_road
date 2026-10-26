extends RefCounted
## Optional timing sink; production scripts are unchanged in the workspace.
static var enabled:=false
static var phase:="setup"
static var calls: Dictionary={}
static var events: Array=[]
static func record(label: String, usec: int, detail: String="") -> void:
	if not enabled: return
	var key:=phase+"::"+label
	if not calls.has(key): calls[key]=[]
	calls[key].append(usec)
	if label.begins_with("nav.grid") or label=="ai.detour" or usec>=5000:
		events.append({"phase":phase,"label":label,"us":usec,"detail":detail,"at_us":Time.get_ticks_usec(),"physics_frame":Engine.get_physics_frames()})
