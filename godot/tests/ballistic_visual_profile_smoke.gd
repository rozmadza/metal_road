extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("BALLISTIC ", "ok: " if ok else "FAIL: ", label)
	if not ok: failures += 1
func run() -> void:
	var world := Node2D.new(); root.add_child(world)
	var vfx := CombatVFX.new(); world.add_child(vfx); vfx.set_process(false)
	for id in ["machine_gun", "heavy_machine_gun"]:
		var cfg := load("res://resources/weapons/"+id+".tres") as WeaponConfig
		var p := cfg.visual_profile
		check(p != null and p.ballistic and p.has_projectile() and p.has_impact(), id+" full profile")
		check(p.clip_valid(p.muzzle_sheet, Vector2i(2,2),4), "four muzzle frames")
		for entry in [[p.muzzle_sheet,Vector2i(2,2)],[p.impact_sheet,Vector2i(3,2)]]:
			var image: Image = entry[0].get_image()
			var grid: Vector2i = entry[1]; var cell := image.get_size()/grid
			var hashes := {}
			for y in grid.y:
				for x in grid.x:
					var frame := image.get_region(Rect2i(Vector2i(x,y)*cell,cell))
					hashes[hash(frame.get_data())]=true
			check(hashes.size()==grid.x*grid.y,"distinct atlas frames")
		var incomplete := p.duplicate(); incomplete.tracer_texture=null
		check(not incomplete.has_projectile(),"partial profile falls back")
		var target := load("res://scenes/Vehicle.tscn").instantiate() as Vehicle
		world.add_child(target); target.freeze=true;target.set_physics_process(false)
		target.position=Vector2(2000,2000)
		var losses: Array[float]=[]
		for assets in [false,true]:
			var config := cfg.duplicate() as WeaponConfig
			if not assets: config.visual_profile=null
			var bullet := Bullet.new();world.add_child(bullet)
			bullet.setup(target.position,Vector2.RIGHT,config,null);bullet.set_physics_process(false)
			check(bullet.damage==cfg.bullet_damage and bullet.radius==cfg.bullet_radius and bullet.velocity.length()==cfg.bullet_speed,"combat fields preserved")
			var before := target.health;var count := vfx.events.size()
			bullet._apply_hit(target,bullet.damage)
			losses.append(before-target.health)
			check(vfx.events.size()==count+1,"one event per vehicle hit")
			check(vfx.events.back().visual_profile==config.visual_profile,"impact profile propagated")
			bullet.free()
		check(is_equal_approx(losses[0],losses[1]),"same damage with/without assets")
		target.free()
		vfx.events.clear()
		var wall_bullet := Bullet.new();world.add_child(wall_bullet)
		wall_bullet.setup(Vector2(37,58),Vector2.RIGHT,cfg,null);wall_bullet.set_physics_process(false)
		wall_bullet._impact()
		check(vfx.events.size()==1 and vfx.events[0].position==Vector2(37,58),"one obstacle impact at bullet contact")
		await process_frame
		for i in 70: vfx.spawn_impact(Vector2.ZERO,Color.WHITE,false,p)
		check(vfx.events.size()==48,"70 asset impacts capped at48")
		vfx._process(0.25)
		check(vfx.events.is_empty(),"impact TTL cleanup")
	check(not WeaponVisualProfile.new().has_projectile(),"empty fallback")
	world.free();await process_frame
	print("BALLISTIC: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
