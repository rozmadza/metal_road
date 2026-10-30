extends SceneTree
## Synthetic textures are test fixtures, never shipped weapon art.
var failures := 0
var world: Node2D
var vfx: CombatVFX

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("ROCKET VISUAL ", "ok: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func fixture_texture(size: Vector2i) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

func run() -> void:
	world = Node2D.new(); root.add_child(world)
	vfx = CombatVFX.new(); world.add_child(vfx)
	var cfg := load("res://resources/weapons/rocket_launcher.tres") as WeaponConfig
	check(cfg.visual_profile != null and cfg.visual_profile.has_projectile() and cfg.visual_profile.has_explosion(), "final textures assigned and valid")
	check(cfg.visual_profile.clip_valid(cfg.visual_profile.muzzle_sheet,Vector2i(3,2),6), "six-frame launch atlas assigned")
	for entry in [[cfg.visual_profile.projectile_body,Vector2i(96,64),1,1], [cfg.visual_profile.exhaust_strip,Vector2i(64,32),1,1], [cfg.visual_profile.muzzle_sheet,Vector2i(288,128),3,2], [cfg.visual_profile.explosion_sheet,Vector2i(1024,512),4,2]]:
		var texture := entry[0] as Texture2D
		check(Vector2i(texture.get_size())==entry[1], "final texture dimensions: "+texture.resource_path.get_file())
		var image := texture.get_image()
		var hashes := {}
		for y in int(entry[3]):
			for x in int(entry[2]):
				var size := Vector2i(image.get_size()) / Vector2i(entry[2],entry[3])
				var frame := image.get_region(Rect2i(Vector2i(x,y)*size,size))
				hashes[hash(frame.get_data())]=true
				check(frame.get_pixel(0,0).a==0.0,"transparent frame corner")
		check(hashes.size()==int(entry[2])*int(entry[3]), "all atlas frames distinct: "+texture.resource_path.get_file())
	var empty := WeaponVisualProfile.new()
	check(not empty.has_projectile() and not empty.has_explosion(), "missing PNGs still retain fallback")
	var profile := WeaponVisualProfile.new()
	profile.projectile_body = fixture_texture(Vector2i(96,64))
	check(not profile.has_projectile(), "incomplete body/exhaust pair retains full legacy rocket")
	profile.exhaust_strip = fixture_texture(Vector2i(64,32))
	profile.muzzle_sheet = fixture_texture(Vector2i(288,128))
	profile.explosion_sheet = fixture_texture(Vector2i(1024,512))
	check(profile.has_projectile() and profile.has_explosion(), "final-layout textures accepted")
	check(not profile.clip_valid(profile.muzzle_sheet,Vector2i.ZERO,6), "invalid grid rejected")
	check(not profile.clip_valid(profile.muzzle_sheet,Vector2i(3,2),7), "frame overflow rejected")
	check(not profile.clip_valid(profile.muzzle_sheet,Vector2i(5,2),6), "uneven atlas rejected")
	check(profile.frame_index(0,8)==0 and profile.frame_index(1,8)==7 and profile.frame_index(-1,8)==0, "animation endpoints clamped")
	var canvas := Node2D.new(); world.add_child(canvas)
	canvas.draw.connect(func():
		profile.draw_projectile(canvas,0.25)
		profile.draw_muzzle(canvas,Vector2(20,0),0.5)
		profile.draw_explosion(canvas,Vector2(200,200),105,0.5))
	canvas.queue_redraw()
	var target := load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
	world.add_child(target); target.add_to_group("combatants")
	target.set_physics_process(false); target.freeze=true; target.gun.set_physics_process(false)
	target.position=Vector2(1000,1000)
	var amounts: Array[float] = []
	for use_assets in [false,true]:
		var config := cfg.duplicate() as WeaponConfig
		config.visual_profile = profile if use_assets else null
		var bullet := Bullet.new(); world.add_child(bullet)
		bullet.setup(Vector2(1030,1000),Vector2.UP,config,null)
		check(bullet.radius==5 and bullet.damage==42 and bullet.splash_radius==105 and bullet.velocity==Vector2(0,-380), "visual profile preserves combat configuration")
		var before := target.health
		bullet._detonate()
		amounts.append(before-target.health)
		check(bullet._explosion_owned_by_vfx==use_assets, "single explosion owner only with ready atlas")
		check(not bullet.is_physics_processing() and bullet.is_inside_tree(), "detonated root retains original tween/cap lifetime")
	check(is_equal_approx(amounts[0],amounts[1]), "same splash damage with/without assets")
	check(vfx.events.filter(func(e): return e.kind==&"explosion").size()==2, "one shared explosion event per detonation")
	for i in 70: vfx.spawn_explosion(Vector2(i,0),Color.WHITE,105,profile)
	check(vfx.events.size()==48,"asset explosions obey existing budget")
	for i in 70: vfx.spawn_impact(Vector2.ZERO)
	check(vfx.events.all(func(e): return e.kind==&"explosion"), "impacts cannot evict asset explosions")
	await create_timer(0.22).timeout
	check(world.get_children().filter(func(n): return n is Bullet).is_empty(), "original bullet tween frees roots")
	await create_timer(0.35).timeout
	check(vfx.events.is_empty() and not vfx.is_processing(), "asset event TTL releases references")
	vfx.free()
	var no_vfx := Bullet.new(); world.add_child(no_vfx)
	var config := cfg.duplicate() as WeaponConfig; config.visual_profile=profile
	no_vfx.setup(Vector2.ZERO,Vector2.RIGHT,config,null); no_vfx._detonate()
	check(not no_vfx._explosion_owned_by_vfx, "no VFX service retains legacy bullet flash")
	for path in BonusWeaponCache.PATHS:
		if path.ends_with("rocket_launcher.tres"): continue
		check((load(path) as WeaponConfig).visual_profile==null,"other weapon remains procedural: "+path.get_file())
	for id in ["biker_pistol", "referee_flamethrower"]:
		check((load("res://resources/weapons/"+id+".tres") as WeaponConfig).visual_profile==null,"special weapon fallback: "+id)
	await create_timer(0.25).timeout
	world.free(); await process_frame
	# The global music service is outside this fixture; stop its Ogg playback
	# before engine teardown so audio-thread references can be released.
	for player in root.get_node("Music").get_children():
		if player is AudioStreamPlayer: player.stop()
	await create_timer(0.1).timeout
	print("ROCKET VISUAL: ","PASS" if failures==0 else "FAIL")
	quit.call_deferred(0 if failures==0 else 1)
