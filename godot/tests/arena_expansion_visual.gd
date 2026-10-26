extends SceneTree
## Automated inspection, not a manual playthrough. Gameplay zoom is unchanged.
var game: Survival
var camera_checks: Array = []
func _initialize() -> void:
	run.call_deferred()
func settle() -> void:
	for frame in 5: await physics_frame
	await process_frame
func shot(name: String, inspect_camera: bool = false) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://"+name+".png")
	if inspect_camera:
		var center:=game.camera.get_screen_center_position()
		var half:=root.get_visible_rect().size/game.camera.zoom/2
		var view:=Rect2(center-half,half*2)
		var outer:=game.arena.get_bounds().grow(game.arena.config.wall_thickness)
		var fits:=outer.grow(2).encloses(view)
		var tutorial_clear:=not game.hud.tutorial.visible or not game.hud.tutorial.get_global_rect().has_point(game.player.get_global_transform_with_canvas().origin)
		camera_checks.append({"image":name,"viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],
			"view":[view.position.x,view.position.y,view.size.x,view.size.y],"zoom":game.camera.zoom.x,"speed":game.player.get_speed(),"inside_walls":fits,"tutorial_clear":tutorial_clear})
		print("CAMERA ",name," zoom=",game.camera.zoom," inside_walls=",fits)
func overview(old: bool) -> void:
	var arena:=Arena.new()
	arena.config=load("res://tests/fixtures/scrapyard_1000x800.tres" if old else "res://resources/default_arena.tres")
	root.add_child(arena)
	if old:
		arena.get_node("ArenaDressing").free()
		var decoration: Node2D=load("res://tests/fixtures/scrapyard_1000x800_dressing.gd").new()
		decoration.set("config",arena.config)
		arena.add_child(decoration)
	for point in arena.config.spike_strip_positions:
		var spike:=load("res://scenes/SpikeStrip.tscn").instantiate() as SpikeStrip
		spike.position=point
		arena.add_child(spike)
	var camera:=Camera2D.new()
	camera.position=arena.get_bounds().get_center()
	# Same scale for BOTH static maps; no cars/gameplay camera in this diagram.
	camera.zoom=Vector2.ONE*0.65
	root.add_child(camera)
	camera.make_current()
	await settle()
	await shot("old-overview" if old else "new-overview")
	camera.free()
	arena.free()
	await settle()
func scene(old: bool) -> void:
	game=load("res://scenes/ArenaBattle.tscn").instantiate() as Survival
	root.add_child(game)
	if old:
		game._initial_arena_config=load("res://tests/fixtures/scrapyard_1000x800.tres")
		game.start_round(1)
		game.arena.get_node("ArenaDressing").free()
		var decoration: Node2D=load("res://tests/fixtures/scrapyard_1000x800_dressing.gd").new()
		decoration.set("config",game.arena.config)
		game.arena.add_child(decoration)
		game.camera.margin=40
		game.hud.avoid_tutorial_overlap=false
		game.camera.set_bounds(game.arena.get_bounds())
	await settle()
	game._reinforcement_timer=999
	game.bonus_spawner.set_physics_process(false)
	for enemy in game._enemies:
		enemy.freeze=true
		enemy.get_node("ArenaBot").set_physics_process(false)
		enemy.gun.set_physics_process(false)
func pose(point: Vector2, name: String, inspect: bool = true) -> void:
	game.player.reset_to(point,0)
	if "supply" in name:
		game.player.activate_temporary_weapon(load("res://resources/weapons/shotgun.tres"),25)
	await settle()
	game.player.freeze=true
	game.camera.target=game.player
	game.camera.snap_to_target()
	await shot(name,inspect)
func drive(name: String) -> void:
	game.player.reset_to(Vector2(400,860),0)
	await settle()
	Input.action_press("accelerate")
	for frame in 180: await physics_frame
	Input.action_release("accelerate")
	await shot(name,true)
func run() -> void:
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1280,720)
	PlayerProfile.path_override="res://expansion_visual_profile.cfg"
	LoadoutProfile.path_override="res://expansion_visual_loadout.cfg"
	CareerSession.clear_selection()
	await overview(true)
	await overview(false)
	await scene(true)
	await pose(Vector2(500,560),"old-center-1280",false)
	game.free()
	await settle()
	await scene(false)
	await pose(Vector2(80,80),"new-spawn-1280")
	# Inspect actual opponent corners without moving those cars.
	for index in game._enemies.size():
		game.camera.target=game._enemies[index]
		game.camera.snap_to_target()
		await shot("new-ai-spawn-"+str(index),true)
	await pose(Vector2(700,620),"new-center-1280")
	await pose(Vector2(700,860),"new-lower-1280")
	game.player.activate_temporary_weapon(load("res://resources/weapons/shotgun.tres"),25)
	for point in game.arena.config.supply_hotspots:
		var item:=load("res://scenes/BonusPickup.tscn").instantiate() as BonusPickup
		item.setup(BonusPickup.Kind.WEAPON,load("res://resources/weapons/rocket_launcher.tres"))
		item.position=point
		game.add_child(item)
	await pose(Vector2(1260,460),"new-supply-right-1280")
	await drive("new-driving-1280")
	root.size=Vector2i(800,600)
	await settle()
	await pose(Vector2(80,80),"new-spawn-800")
	await pose(Vector2(700,620),"new-center-800")
	await pose(Vector2(700,860),"new-lower-800")
	await pose(Vector2(150,460),"new-supply-left-800")
	await drive("new-driving-800")
	FileAccess.open("res://camera-checks.json",FileAccess.WRITE).store_string(JSON.stringify(camera_checks,"  "))
	print("ARENA EXPANSION GUI COMPLETE")
	quit(1 if camera_checks.any(func(c):return not c.inside_walls or not c.tutorial_clear) else 0)
