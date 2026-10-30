extends SceneTree
var failures:=0
var rows:Array=[]
var baseline:=false
func _initialize() -> void: run.call_deferred()
func check(ok:bool,label:String) -> void:
	if not ok: failures+=1;printerr("REVERSE RESPONSE FAIL: ",label)
func input_event(mode:String,gas:bool,value:float) -> void:
	if mode=="keyboard":
		var event:=InputMap.action_get_events(&"accelerate" if gas else &"brake")[0].duplicate() as InputEventKey
		event.pressed=value>0
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	else:
		var event:=InputEventJoypadMotion.new();event.axis=JOY_AXIS_TRIGGER_RIGHT if gas else JOY_AXIS_TRIGGER_LEFT;event.axis_value=value
		Input.parse_input_event(event)
		Input.flush_buffered_events()
func run() -> void:
	baseline="--baseline" in OS.get_cmdline_user_args()
	InputBindings.ensure_controller_defaults()
	var handler:=InputHandler.new()
	for id in ["raider","bastion","behemoth"]:
		for mode in ["keyboard","gamepad"]:
			for broken in [false,true]:
				var car:=load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
				car.config=LoadoutProfile.vehicle_config(StringName(id)).duplicate()
				root.add_child(car);car.position=Vector2(2000,2000)
				if broken: car.damage.engine=0;car.damage.wheels=0
				await physics_frame
				car.linear_velocity=Vector2(car.config.max_speed,0)
				input_event(mode,false,1)
				var stop:=-1.0;var thrust:=-1.0;var negative:=-1.0;var early:=0.0
				for frame in 360:
					var commands:=handler.get_commands()
					check(commands.brake>0.9 and commands.throttle==0,"input route "+mode)
					car.apply_player_control(commands.throttle,commands.brake,0,false,1.0/60)
					if thrust<0 and car.throttle<0: thrust=frame/60.0
					await physics_frame
					var elapsed:=(frame+1)/60.0
					if frame==17:early=car.get_forward_speed()
					if stop<0 and absf(car.get_forward_speed())<=2:stop=elapsed
					if car.get_forward_speed() < -2:
						negative=elapsed;break
				rows.append({"vehicle":id,"input":mode,"broken":broken,"stop":stop,"reverse_thrust":thrust,"negative":negative,"lag":negative-stop,"speed_0_3":early})
				# Damaged/heavy classes have a lower initial maximum. A universal
				# 0.7s stop bound is invalid for them; retain a positive road-speed
				# interval and require gear selection only after the stop gate.
				check(stop>0.3 and negative>stop+0.1 and early>car.config.max_speed*0.25,"braking inertia retained")
				check(negative-stop < (0.55 if baseline else 0.3),"response window")
				# S->W clears selector immediately; torque/thrust still uses physics ramp.
				input_event(mode,false,0);input_event(mode,true,1)
				var commands:=handler.get_commands();car.apply_player_control(commands.throttle,commands.brake,0,false,1.0/60)
				check(not car._player_reverse and car.throttle>0,"S to W selector")
				input_event(mode,true,0)
				car.free();await process_frame
	# Lateral motion must not restart the stationary longitudinal timer.
	var drift:=load("res://scenes/Vehicle.tscn").instantiate() as Vehicle;root.add_child(drift)
	drift.freeze=true;drift.linear_velocity=Vector2(0,15)
	for frame in 12: drift.apply_player_control(0,1,0,false,1.0/60)
	check(drift._player_reverse != baseline,"lateral slide does not postpone new selection")
	drift.free()
	FileAccess.open("res://driving-reverse-results.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	print("REVERSE RESPONSE: ","PASS" if failures==0 else "FAIL"," ",JSON.stringify(rows))
	quit(0 if failures==0 else 1)
