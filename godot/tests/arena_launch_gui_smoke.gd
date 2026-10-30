extends SceneTree
## Real Control input routing, never pressed.emit() or launch-handler calls.
## Run graphically. Saves/data are isolated from the player's normal profile.
const BonusCache = preload("res://scripts/bonus_weapon_cache.gd")
var failures:=0
var transitions:=0
var presses:=0
var output:="/tmp/arena-launch-gui/"
var records:Array=[]
var shots:Array=[]

func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	print("ARENA GUI ","ok: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func capture(label:String) -> void:
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		shots.append({"name":label,"image":root.get_texture().get_image()})
func wait_scene(path:String) -> bool:
	var until:=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<until:
		if current_scene!=null and current_scene.scene_file_path==path and not SceneTransition.is_busy():
			await process_frame
			return true
		await process_frame
	check(false,"timeout reaching "+path)
	return false
func find_text(node:Node,text:String) -> Button:
	if node is Button and node.text==text and node.is_visible_in_tree():return node
	for child in node.get_children():
		var found:=find_text(child,text)
		if found!=null:return found
	return null
func click(button:Button,repeat_click:=false) -> void:
	if button==null:
		check(false,"button exists");return
	check(button.is_visible_in_tree() and not button.disabled,"clickable "+button.text)
	# A newly opened native dialog needs the OS focus/layout events dispatched.
	for _frame in 3:await process_frame
	var record:={"button":str(button.get_path()),"text":button.text,"disabled":button.disabled,"mouse_filter":button.mouse_filter,"connections":button.pressed.get_connections().size(),"before_press_count":presses}
	button.pressed.connect(func():presses+=1)
	var viewport:=button.get_viewport()
	var input_window:=button.get_window()
	var center:=button.get_global_rect().get_center()
	# Embedded Window controls use local coordinates, while native input is
	# addressed to the containing OS window (often window_id=0).
	while input_window.is_embedded():
		center+=Vector2(input_window.position)
		input_window=input_window.get_parent().get_window()
	var window_id:=input_window.get_window_id()
	record.position=[center.x,center.y];record.window_id=window_id
	var motion:=InputEventMouseMotion.new();motion.position=center;motion.global_position=center
	motion.window_id=window_id
	Input.parse_input_event(motion)
	var hovered:=viewport.gui_get_hovered_control()
	record.hovered=str(hovered.get_path()) if hovered!=null else ""
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=center;event.global_position=center
		event.window_id=window_id
		Input.parse_input_event(event)
	# A second real click in the same frame must not start a duplicate transition.
	if repeat_click:
		for pressed in [true,false]:
			var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=center;event.global_position=center
			event.window_id=window_id
			Input.parse_input_event(event)
	await process_frame
	record.after_press_count=presses;record.busy=SceneTransition.is_busy();records.append(record)
	check(presses>int(record.before_press_count),"pressed received through GUI hit test")
	await process_frame
func key(code:Key) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
		event.window_id=root.get_window_id()
		Input.parse_input_event(event)
		if pressed and code==KEY_SPACE:
			for _frame in 3:await physics_frame
	await process_frame
func accept(button:Button,joypad:bool) -> void:
	button.grab_focus()
	button.pressed.connect(func():presses+=1)
	var before:=presses
	if joypad:
		for pressed in [true,false]:
			var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_A;event.device=0;event.pressed=pressed
			Input.parse_input_event(event)
		await process_frame
	else:await key(KEY_ENTER)
	check(presses>before,"focused button accepted by "+("joypad event" if joypad else "Enter key event"))
func pause_action(text:String) -> void:
	await key(KEY_ESCAPE)
	var overlay:PauseOverlay=current_scene.hud.pause_overlay
	check(overlay.visible and paused,"pause opened via Escape")
	await click(find_text(overlay,text))
func launch(menu_button:String,accept_mode:String="mouse") -> bool:
	await click(current_scene.get_node("%"+menu_button))
	if not await wait_scene("res://scenes/PreRace.tscn"):return false
	var setup:=current_scene as PreRaceSetup
	var button:=setup.get_node("%StartButton") as Button
	check(setup.selected_vehicle_id!=&"" and PlayerProfile.is_owned(&"vehicle",setup.selected_vehicle_id),"selected vehicle owned")
	await capture("pre-race-"+accept_mode)
	var before:=transitions
	if accept_mode=="mouse":await click(button,true)
	else:await accept(button,accept_mode=="joypad")
	var path:="res://scenes/ArenaBattle.tscn" if menu_button=="SurvivalButton" else "res://scenes/Main.tscn"
	if not await wait_scene(path):return false
	check(transitions==before+1,"exactly one scene change for launch")
	check(root.get_children().filter(func(n):return n.scene_file_path==path).size()==1,"one match scene instance")
	check(not root.get_node("Transition/LoadingOverlay").visible,"loading overlay closed")
	var car:Vehicle=current_scene.player if current_scene is Survival else current_scene.vehicle
	check(car.alive and car.config!=null,"player ready and alive")
	check(root.get_node("Music").state==(1 if current_scene is Survival else 3),"match music state")
	await capture("match-"+accept_mode)
	return true
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if not args.is_empty():output=args[0].trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(output)
	PlayerProfile.path_override=output+"profile.cfg";LoadoutProfile.path_override=output+"loadout.cfg"
	MainMenu.settings_path_override=output+"settings.cfg"
	if not FileAccess.file_exists(PlayerProfile.path_override):PlayerProfile.save({"credits":0,"vehicles":[&"raider"],"weapons":[&"machine_gun"],"vehicle_states":{},"weapon_upgrades":[]})
	if not FileAccess.file_exists(LoadoutProfile.path_override):LoadoutProfile.save_ids(&"raider",&"machine_gun")
	var settings:=ConfigFile.new();settings.set_value("settings","fullscreen",false);settings.set_value("settings","resolution_index",0);settings.save(MainMenu.settings_path_override)
	AudioServer.set_bus_mute(0,true)
	scene_changed.connect(func():transitions+=1)
	change_scene_to_file("res://scenes/MainMenu.tscn")
	if not await wait_scene("res://scenes/MainMenu.tscn"):finish();return
	await capture("main-menu")
	if not await launch("SurvivalButton"):finish();return
	await pause_action("В ГЛАВНОЕ МЕНЮ")
	if not await wait_scene("res://scenes/MainMenu.tscn"):finish();return
	check(root.get_node("Music").state==0,"menu music restored")
	# GUI Menu -> Garage -> PreRace -> Survival, keyboard accept.
	await click(current_scene.get_node("%GarageButton"))
	if not await wait_scene("res://scenes/Garage.tscn"):finish();return
	await click(current_scene.get_node("%SurvivalButton"))
	if not await wait_scene("res://scenes/PreRace.tscn"):finish();return
	await accept(current_scene.get_node("%StartButton"),false)
	if not await wait_scene("res://scenes/ArenaBattle.tscn"):finish();return
	var old_generation:int=current_scene._arena_generation
	await pause_action("НАЧАТЬ ЗАНОВО")
	await process_frame;await physics_frame;await process_frame
	check(current_scene._arena_generation>old_generation and current_scene._round==1,"restart from GUI pause rebuilds session")
	await pause_action("В ГЛАВНОЕ МЕНЮ")
	if not await wait_scene("res://scenes/MainMenu.tscn"):finish();return
	var saved_vehicle:StringName=LoadoutProfile.read_ids().vehicle
	LoadoutProfile.save_ids(saved_vehicle,&"rocket_launcher")
	if not await launch("SurvivalButton","joypad"):finish();return
	check(LoadoutProfile.read_ids().weapon==&"rocket_launcher","saved weapon id preserved")
	var rocket:=BonusCache.get_config("res://resources/weapons/rocket_launcher.tres")
	check(rocket!=null and rocket.visual_profile.has_projectile() and rocket.visual_profile.has_explosion() and rocket.visual_profile.muzzle_sheet!=null,"all four Rocket PNGs preloaded")
	# Starting weapons are intentionally disabled by game design. Test grant
	# validates the rocket after GUI launch without changing that rule.
	current_scene.player.activate_temporary_weapon(rocket,30)
	await key(KEY_SPACE)
	check(current_scene.bullets.get_child_count()>0,"Space key after GUI launch fires the preloaded rocket")
	await capture("rocket-after-gui-launch")
	await pause_action("В ГЛАВНОЕ МЕНЮ")
	if not await wait_scene("res://scenes/MainMenu.tscn"):finish();return
	if not await launch("RaceButton","keyboard"):finish();return
	await pause_action("В ГЛАВНОЕ МЕНЮ")
	if not await wait_scene("res://scenes/MainMenu.tscn"):finish();return
	# Career's driver and story screens are navigated with GUI clicks as well.
	await click(current_scene.get_node("%CareerButton"))
	var until:=Time.get_ticks_msec()+10000
	while (current_scene==null or not current_scene.scene_file_path in [DriverRoster.SELECT_SCENE,CareerSession.CAREER_SCENE]) and Time.get_ticks_msec()<until:await process_frame
	if current_scene is DriverSelect:
		await click(current_scene.get_node("%ConfirmButton"))
	if not await wait_scene(CareerSession.CAREER_SCENE):finish();return
	await click(current_scene.get_node("%StartButton"))
	if not await wait_scene("res://scenes/PreRace.tscn"):finish();return
	await click(current_scene.get_node("%StartButton"))
	until=Time.get_ticks_msec()+10000
	while (current_scene==null or not current_scene.scene_file_path in [CareerStory.SCENE,"res://scenes/Main.tscn"]) and Time.get_ticks_msec()<until:await process_frame
	if current_scene!=null and current_scene.scene_file_path==CareerStory.SCENE:await click(find_text(current_scene,"ПРОПУСТИТЬ"))
	if not await wait_scene("res://scenes/Main.tscn"):finish();return
	check(not current_scene.career_event.is_empty(),"Career GUI launch retains event")
	await capture("career-match")
	await pause_action("В ГЛАВНОЕ МЕНЮ")
	if not await wait_scene(CareerSession.CAREER_SCENE):finish();return
	await click(current_scene.get_node("%BackButton"))
	if not await wait_scene("res://scenes/MainMenu.tscn"):finish();return
	await capture("returned-menu")
	finish()
func finish() -> void:
	for item in shots:item.image.save_png(output+item.name+".png")
	FileAccess.open(output+"input-trace.json",FileAccess.WRITE).store_string(JSON.stringify({"display":DisplayServer.get_name(),"failures":failures,"transitions":transitions,"input_events":records},"\t"))
	if current_scene!=null:current_scene.free()
	for player in root.get_node("Music").get_children():
		if player is AudioStreamPlayer:player.stop()
	print("ARENA LAUNCH GUI: ","PASS" if failures==0 else "FAIL")
	quit.call_deferred(0 if failures==0 else 1)
