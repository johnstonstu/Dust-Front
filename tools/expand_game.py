"""One-time migration of the first playable to the campaign build."""
from pathlib import Path
import re
p = Path(__file__).resolve().parents[1] / 'game.gd'
s = p.read_text()
def function(name, body):
    global s
    start = s.index('func '+name+'(')
    end = s.find('\nfunc ', start+1)
    if end < 0: end = len(s)
    s = s[:start] + body.strip() + '\n' + s[end:]

s = s.replace('const TERRAIN_SHADER = preload("res://terrain.gdshader")', '''const Campaign = preload("res://campaign.gd")
const Arena = preload("res://arena.gd")
const CombatAudio = preload("res://combat_audio.gd")
const HangarUI = preload("res://hangar_ui.gd")
const Radar = preload("res://radar.gd")
var profile = Campaign.new()
var arena
var audio
var hangar
var radar
var mission_index := 0
var loaded_mission := -1
var missile_ammo := 20
var warning_timer := 0.0
var primary_id := 0
var secondary_id := 0
var prior_lock: Node3D
var capture_kind := "gameplay"
var total_reward := 0
var enemy_material: StandardMaterial3D''')
function('_ready', '''func _ready() -> void:
	rng.seed = 8801
	var args := OS.get_cmdline_user_args()
	smoke_test = "--smoke-test" in args
	for key in ["gameplay","menu","pause","alpine","volcanic"]:
		if ("--capture-"+key) in args or (key == "gameplay" and "--capture-test" in args):
			capture_test = true
			capture_kind = key
	if smoke_test or capture_test:
		profile.save_path = "user://qa-campaign.cfg"
	else:
		profile.load_profile()
	if capture_test:
		profile.unlocked = 3
		profile.xp = 1000
		profile.credits = 850
		if capture_kind == "alpine": mission_index = 1
		if capture_kind == "volcanic": mission_index = 2
	audio = CombatAudio.new()
	add_child(audio)
	audio.setup(profile)
	build_world()
	build_player()
	build_ui()
	if smoke_test:
		run_smoke_test.call_deferred()
	elif capture_test and capture_kind != "menu":
		start_game()
		if capture_kind == "pause": set_pause(true)
''')
function('ground_height','''func ground_height(x: float, z: float) -> float:
	return arena.height_at(x,z) if is_instance_valid(arena) else 0.0''')
function('build_world','''func build_world() -> void:
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
	arena = Arena.new()
	add_child(arena)
	arena.build(mission_index)
	loaded_mission = mission_index
	if enemy_material == null:
		enemy_material = mat(Color("8d9995"),.55)
		enemy_material.albedo_texture = load("res://assets/textures/metal_color.png")
		enemy_material.normal_enabled = true
		enemy_material.normal_texture = load("res://assets/textures/metal_normal.png")
		enemy_material.uv1_triplanar = true''')
start=s.index('\trotor_audio = AudioStreamPlayer.new()')
end=s.index('\tupdate_camera(1.0)',start)
s=s[:start]+ '\tcraft.position = Vector3(0, ground_height(0,40)+42, 40)\n'+s[end:]
function('build_ui','''func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root_ui := Control.new()
	canvas.add_child(root_ui)
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading_label := label_at(root_ui, Vector2(28,20),24,Color("ebd9a9"))
	heading_label.text = "APACHE / DUST FRONT"
	hud = label_at(root_ui,Vector2(28,58),17,Color("dfebe2"))
	status = label_at(root_ui,Vector2(28,167),17,Color("eebc6a"))
	crosshair = label_at(root_ui,Vector2.ZERO,28,Color("b6fbd6"))
	crosshair.text = "+"
	target_marker = label_at(root_ui,Vector2.ZERO,18,Color("ffbf72"))
	var help := label_at(root_ui,Vector2.ZERO,14,Color("d0d8d4"))
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 28
	help.offset_top = -36
	help.text = "W/S speed · A/D strafe · Mouse aim · Space/C altitude · LMB cannon · RMB secondary · Esc pause · M mute"
	radar = Radar.new()
	root_ui.add_child(radar)
	radar.game = self
	radar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	radar.offset_left = -192
	radar.offset_top = 20
	radar.offset_right = -28
	radar.offset_bottom = 184
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hangar = HangarUI.new()
	root_ui.add_child(hangar)
	hangar.setup(self)
	hangar.open("hangar")''')
function('start_game','''func start_game() -> void:
	mission_index = clampi(mission_index,0,profile.unlocked-1)
	clear_combat()
	if loaded_mission != mission_index:
		build_world()
	health = profile.max_health()
	kills = 0
	wave = 1
	heading = 0
	pitch = 0.03
	velocity = Vector3.ZERO
	craft.position = Vector3(0,ground_height(0,40)+42,40)
	craft.rotation = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	cannon_timer = 0
	rocket_timer = 0
	primary_id = profile.primary
	secondary_id = profile.secondary
	missile_ammo = Campaign.SECONDARY[secondary_id].ammo
	active = true
	paused = false
	elapsed = 0
	next_wave = 0
	prior_lock = null
	target = null
	hangar.hide()
	if not smoke_test and not capture_test:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	audio.flight(true)
	audio.cue("click")
	spawn_wave()
	update_camera(1.0)

func clear_combat() -> void:
	for array in [enemies,shots,effects]:
		for item in array:
			if is_instance_valid(item.node): item.node.queue_free()
		array.clear()
	target = null
	prior_lock = null

func return_to_hangar() -> void:
	active = false
	paused = false
	audio.flight(false)
	audio.set_pause(false)
	clear_combat()
	profile.save_profile()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hangar.open("hangar")''')
function('set_pause','''func set_pause(value: bool) -> void:
	paused = value
	audio.set_pause(value)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or smoke_test or capture_test else Input.MOUSE_MODE_CAPTURED
	if value:
		hangar.open("paused")
	else:
		hangar.hide()''')
s=s.replace('AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))','profile.muted = not profile.muted\n\t\t\taudio.apply_levels()\n\t\t\tprofile.save_profile()')
s=s.replace('elif event.keycode == KEY_R:', 'elif event.keycode == KEY_R and active:')
function('spawn_wave','''func spawn_wave() -> void:
	var count := 5 + wave * 2 + mission_index * 2
	for i in range(count):
		var angle := float(i)/count*TAU
		var pos := craft.position + Vector3(sin(angle)*160,15+i*3,-150+cos(angle)*65)
		pos.y = maxf(pos.y,ground_height(pos.x,pos.z)+30)
		var kind := "scout"
		if i%3 == 1: kind = "interceptor"
		if i%4 == 3 and (wave > 1 or mission_index > 0): kind = "gunship"
		if wave == 3 and i == 0: kind = "ace"
		spawn_enemy(pos,kind)
	missile_ammo = Campaign.SECONDARY[secondary_id].ammo
	audio.cue("reward")''')
function('spawn_enemy','''func spawn_enemy(pos: Vector3, kind: String = "scout") -> void:
	var enemy := Node3D.new()
	add_child(enemy)
	enemy.position = pos
	var spinners: Array[Node3D] = []
	var hull := SphereMesh.new()
	hull.radius = 1.5
	hull.height = 1.7
	shape(enemy,hull,enemy_material)
	if kind == "interceptor":
		var mesh := ArrayMesh.new()
		var vertices := PackedVector3Array([Vector3(0,0,-5),Vector3(-5,0,2),Vector3(5,0,2),Vector3(0,1,1),Vector3(0,-.5,1)])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vertices
		arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,3,0,3,2,1,2,3,0,4,1,0,2,4,1,4,2])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
		shape(enemy,mesh,enemy_material)
		box(enemy,Vector3(.2,2,2),Color("aa7650"),Vector3(0,1,2))
	else:
		box(enemy,Vector3(6,.22,1),Color("57646a"),Vector3.ZERO)
		for side in [-1,1]:
			var ring := TorusMesh.new()
			ring.inner_radius = .7
			ring.outer_radius = 1.1
			shape(enemy,ring,enemy_material,Vector3(side*2.6,0,0))
			var blades := box(enemy,Vector3(1.8,.04,.13),Color("96978c"),Vector3(side*2.6,.15,0))
			spinners.append(blades)
		if kind in ["gunship","ace"]:
			box(enemy,Vector3(2.2,1.6,5),Color("60635b"),Vector3(0,0,.6))
			for side in [-1,1]:
				box(enemy,Vector3(.45,.45,4),Color("342f30"),Vector3(side*1.6,-.5,-1))
			enemy.scale = Vector3.ONE*(1.9 if kind == "ace" else 1.4)
	for side in [-1,1]:
		var lens := SphereMesh.new()
		lens.radius = .23
		lens.height = .46
		shape(enemy,lens,mat(Color("ff5034"),0,3),Vector3(side*.7,.1,-1.4))
	var hp: float = {"scout":70.0,"interceptor":95.0,"gunship":240.0,"ace":640.0}[kind] * (1+mission_index*.18)
	enemies.append({"node":enemy,"kind":kind,"hp":hp,"max_hp":hp,"radius":5.5 if kind == "ace" else 4.2 if kind == "gunship" else 3.0,"cooldown":rng.randf_range(3,6),"phase":rng.randf()*TAU,"spinners":spinners})''')
s=s.replace('frame_count > 100','frame_count > 35')
s=s.replace('forward * throttle * 46 + right * strafe * 28 + Vector3.UP * climb * 20','forward * throttle * profile.speed() + right * strafe * 34 + Vector3.UP * climb * 26')
s=s.replace('clampf(craft.position.x, -440, 440)','clampf(craft.position.x, -Arena.LIMIT, Arena.LIMIT)').replace('clampf(craft.position.z, -440, 440)','clampf(craft.position.z, -Arena.LIMIT, Arena.LIMIT)').replace('minf(craft.position.y, 180)','minf(craft.position.y, 380)')
s=s.replace('rotor_audio.pitch_scale = 0.9 + velocity.length() / 180','audio.update_flight(velocity.length(),delta)')
s=s.replace('rocket_timer <= 0:\n\t\tfire(true)','rocket_timer <= 0 and missile_ammo > 0:\n\t\tfire(true)')
old='''		if next_wave > 3.0:
			wave += 1
			health = minf(100, health + 20)
			next_wave = 0
			spawn_wave()'''
new='''		if next_wave > 4.0:
			next_wave = 0
			if wave >= 3:
				finish_mission()
			else:
				wave += 1
				health = minf(profile.max_health(), health + 25)
				spawn_wave()
	warning_timer = maxf(0,warning_timer-delta)
	if health < profile.max_health()*.25 and warning_timer <= 0:
		warning_timer = 3.0
		audio.cue("warning")'''
assert old in s
s=s.replace(old,new)
s=s.replace('var best := 0.94','var best := 0.97').replace(' < 400:', ' < 550:')
s=s.replace('\t\taim_point = target.position\n','\t\taim_point = target.position\n\tif is_instance_valid(target) and target != prior_lock:\n\t\taudio.cue("lock")\n\tprior_lock = target\n')
function('fire','''func fire(rocket: bool) -> void:
	var origin := craft.position - craft.basis.z * 5 + Vector3.DOWN * .7
	var direction := (aim_point-origin).normalized()
	if rocket:
		var weapon: Dictionary = Campaign.SECONDARY[secondary_id]
		var count := mini(3,missile_ammo) if secondary_id == 1 else 1
		if missile_ammo <= 0: return
		for i in range(count):
			var dir := direction.rotated(Vector3.UP,(i-(count-1)*.5)*.035)
			spawn_shot(origin+craft.basis.x*(i-(count-1)*.5),dir,false,true,null if secondary_id == 1 else target)
			shots.back().damage = weapon.damage
			shots.back().splash = 13.0 if secondary_id == 2 else 8.0 if secondary_id == 1 else 3.0
		missile_ammo -= count
		rocket_timer = weapon.cooldown
		play_sound("rocket",origin,-8)
		shake = .35
	else:
		spawn_shot(origin,direction,false,false)
		shots.back().damage = Campaign.PRIMARY[primary_id].damage*(1+profile.cannon*.15)
		cannon_timer = Campaign.PRIMARY[primary_id].interval
		play_sound("cannon",origin,-17 if primary_id == 1 else -11)
		shake = .12''')
s=s.replace('"trail": 0.0}', '"trail": 0.0, "damage": 9.0 if hostile else 110.0 if rocket else 25.0, "splash": 3.0 if rocket else 0.0}')
function('update_enemies','''func update_enemies(delta: float) -> void:
	for e in enemies:
		var node: Node3D = e.node
		var toward: Vector3 = craft.position-node.position
		var distance := toward.length()
		var direction := toward.normalized()
		var tangent := direction.cross(Vector3.UP).normalized()
		var speed: float = {"scout":20.0,"interceptor":45.0,"gunship":13.0,"ace":18.0}[e.kind]
		var desired := direction*(1.0 if distance > 120 else -.25)+tangent*.8
		if e.kind == "interceptor":
			desired = direction*(1.0 if distance > 80 else -.6)+tangent*.6
		node.position += desired*speed*delta
		node.position.y += sin(elapsed*1.7+e.phase)*delta*2
		node.position.y = maxf(node.position.y,ground_height(node.position.x,node.position.z)+18)
		node.position.x = clampf(node.position.x,-1200,1200)
		node.position.z = clampf(node.position.z,-1200,1200)
		if distance > .1: node.look_at(craft.position)
		for spinner in e.spinners:
			spinner.rotate_y(delta*35)
		e.cooldown -= delta
		if e.cooldown <= 0 and distance < 390:
			e.cooldown = rng.randf_range(3.0,5.0) if e.kind in ["scout","interceptor"] else 2.5
			var predicted := craft.position+velocity*minf(distance/95,.7)
			var aim := (predicted-node.position).normalized()
			var count := 3 if e.kind in ["gunship","ace"] else 1
			for i in range(count):
				spawn_shot(node.position+direction*6,aim.rotated(Vector3.UP,(i-(count-1)*.5)*.045),true,false)
				shots.back().damage = 12.0 if e.kind == "ace" else 8.0
			play_sound("heavy" if count > 1 else "enemy",node.position,-16)
		if distance < 5:
			take_damage(delta*20)''')
# New collision code resolves splash kills after collecting victims, avoiding mutation during iteration.
function('update_shots','''func update_shots(delta: float) -> void:
	for i in range(shots.size()-1,-1,-1):
		var b := shots[i]
		var node: Node3D = b.node
		var previous := node.position
		if b.rocket and is_instance_valid(b.target) and not b.target.is_queued_for_deletion():
			var desired: Vector3 = (b.target.position-previous).normalized()*120
			b.velocity = b.velocity.lerp(desired,minf(delta*3.5,1))
			node.look_at(previous+b.velocity)
		node.position += b.velocity*delta
		b.ttl -= delta
		var hit := false
		if b.hostile:
			if segment_distance(previous,node.position,craft.position) < 2.8:
				take_damage(b.damage)
				hit = true
		else:
			var victim: Dictionary = {}
			for e in enemies:
				if segment_distance(previous,node.position,e.node.position) < e.radius:
					victim = e
					break
			if not victim.is_empty():
				projectile_hits += 1
				var impact: Vector3 = victim.node.position
				var victims: Array[Dictionary] = [victim]
				if b.splash > 0:
					for e in enemies:
						if e != victim and e.node.position.distance_to(impact) < b.splash:
							victims.append(e)
				for e in victims:
					damage_enemy(e,b.damage if e == victim else b.damage*.65)
				burst(impact,1.7 if b.rocket else .7)
				hit = true
		if b.rocket:
			b.trail += delta
			if b.trail > .045:
				b.trail = 0
				puff(previous,Vector3.UP,.32,Color("aaa393"),.65)
		if node.position.y < ground_height(node.position.x,node.position.z):
			hit = true
			burst(node.position,1.5 if b.rocket else .4)
		if hit or b.ttl <= 0:
			node.queue_free()
			shots.remove_at(i)

func damage_enemy(enemy: Dictionary, damage: float) -> void:
	if enemy not in enemies: return
	enemy.hp -= damage
	if enemy.hp <= 0:
		var pos: Vector3 = enemy.node.position
		burst(pos,6 if enemy.kind == "ace" else 4)
		play_sound("heavy_explosion" if enemy.kind in ["gunship","ace"] else "explosion",pos,-3)
		enemy.node.queue_free()
		enemies.erase(enemy)
		kills += 1
		var old_rank: int = profile.rank()
		profile.earn_kill(enemy.kind)
		if profile.rank() > old_rank: audio.cue("reward")''')
function('play_sound','''func play_sound(sound_name: String, pos: Vector3, volume: float) -> void:
	audio.play_at(sound_name,pos,volume)''')
function('take_damage','''func take_damage(amount: float) -> void:
	if not active: return
	health = maxf(0,health-amount)
	shake = .5
	if amount >= 5: play_sound("hit",craft.position,-8)
	if health <= 0:
		active = false
		paused = false
		audio.flight(false)
		profile.save_profile()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hangar.open("defeat","Wave %d / %d hostiles destroyed. XP and credits retained. Upgrade your aircraft and try again." % [wave,kills])

func finish_mission() -> void:
	active = false
	paused = false
	audio.flight(false)
	var reward: int = profile.complete_mission(mission_index)
	total_reward = reward
	audio.cue("reward")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var note := "%s cleared / %d kills / +%d credits. Choose your next sortie below." % [Campaign.MISSIONS[mission_index].name,kills,reward]
	mission_index = mini(mission_index+1,2)
	hangar.open("victory",note)''')
function('update_hud','''func update_hud() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	crosshair.position = viewport_size/2-Vector2(9,19)
	hud.text = "HULL %03d / %03d   WAVE %d/3   KILLS %02d\\nSPEED %03d km/h   AGL %03d m   RANK %d\\nSECONDARY %02d   %s\\n%s" % [int(health),int(profile.max_health()),wave,kills,int(velocity.length()*3.6),int(craft.position.y-ground_height(craft.position.x,craft.position.z)),profile.rank(),missile_ammo,"READY" if rocket_timer <= 0 else "%.1fs" % rocket_timer,Campaign.MISSIONS[loaded_mission].name]
	status.text = "%d HOSTILES / %s" % [enemies.size(),"TARGET LOCK" if is_instance_valid(target) else "SEARCHING"]
	if active and enemies.is_empty(): status.text = "OPERATION CLEAR" if wave == 3 else "RESUPPLY / NEXT WAVE IN %d" % maxi(1,int(5-next_wave))
	if active and craft.position.y-ground_height(craft.position.x,craft.position.z) < 10: status.text += " / TERRAIN — CLIMB"
	if abs(craft.position.x)>1120 or abs(craft.position.z)>1120: status.text += " / ARENA BOUNDARY"
	if not profile.last_error.is_empty(): status.text = profile.last_error
	target_marker.visible = active and is_instance_valid(target) and not target.is_queued_for_deletion() and not camera.is_position_behind(target.position)
	if target_marker.visible:
		target_marker.text = "[ LOCK ]"
		for e in enemies:
			if e.node == target: target_marker.text = "[ %s %d%% ]" % [e.kind.to_upper(),int(e.hp/e.max_hp*100)]
		target_marker.position = camera.unproject_position(target.position)-Vector2(60,30)
	radar.queue_redraw()''')
function('run_smoke_test','''func run_smoke_test() -> void:
	start_game()
	assert(rotor != null and tail_rotor != null and turret != null)
	assert(enemies.size() == 7,"Expanded wave did not spawn")
	var e := enemies[0]
	e.node.position = Vector3(0,80,-60)
	e.hp = 20
	spawn_shot(Vector3(0,80,-40),Vector3.FORWARD,false,false)
	update_shots(.1)
	assert(kills == 1 and projectile_hits == 1,"Swept projectile collision failed")
	assert(profile.xp == 35 and profile.credits == 30,"Kill rewards failed")
	spawn_shot(craft.position+Vector3(0,0,10),Vector3.FORWARD,true,false)
	update_shots(.15)
	assert(health == 91,"Incoming damage failed")
	var homing_target: Node3D = enemies[0].node
	homing_target.position = Vector3(25,80,-150)
	spawn_shot(Vector3(0,80,0),Vector3.FORWARD,false,true,homing_target)
	update_shots(.05)
	assert(shots.back().velocity.x > 0,"Homing failed")
	profile.xp = 750
	profile.credits = 1000
	assert(profile.buy("armor") and profile.max_health() == 125,"Upgrade purchase failed")
	var balance: int = profile.credits
	profile.credits = 0
	assert(not profile.buy("engine"),"Unaffordable upgrade allowed")
	profile.credits = balance
	profile.primary = 2
	profile.secondary = 1
	start_game()
	assert(health == 125 and primary_id == 2,"Loadout not applied")
	aim_point = craft.position+Vector3(0,0,-100)
	var before := shots.size()
	fire(true)
	assert(shots.size() == before+3 and missile_ammo == 27,"Salvo/ammunition failed")
	for b in shots: assert(b.damage == 65,"Loadout damage failed")
	for enemy in enemies: enemy.node.queue_free()
	enemies.clear()
	next_wave = 4.0
	update_game(1.0/60)
	assert(wave == 2 and enemies.size() == 9 and missile_ammo == 30,"Wave/resupply failed")
	set_pause(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var center: Vector2 = hangar.panel.get_global_rect().get_center()
	assert(center.distance_to(get_viewport().get_visible_rect().size/2)<2,"Pause panel is not centered")
	set_pause(false)
	wave = 3
	for enemy in enemies: enemy.node.queue_free()
	enemies.clear()
	next_wave = 4.0
	update_game(1.0/60)
	assert(not active and profile.unlocked == 2 and 0 in profile.completed,"Mission unlock failed")
	var restored = Campaign.new()
	restored.save_path = profile.save_path
	restored.load_profile()
	assert(restored.xp == profile.xp and restored.credits == profile.credits and restored.armor == 1 and restored.secondary == 1,"Save/load failed")
	for index in [1,2]:
		profile.unlocked = 3
		mission_index = index
		start_game()
		assert(arena.biome == index and enemies.size() == 7+index*2)
		for i in range(60): update_game(1.0/60)
	set_pause(true)
	return_to_hangar()
	assert(not active and not paused and hangar.visible,"Hangar transition failed")
	start_game()
	take_damage(500)
	assert(not active and hangar.visible,"Game over failed")
	start_game()
	assert(health == 125 and kills == 0,"Restart failed")
	DirAccess.remove_absolute(profile.save_path)
	print("SMOKE PASS: combat, homing, salvo/ammo, rewards, upgrade gating, loadouts, centered pause, resupply, mission unlock, save/load, all biomes, defeat and restart")
	get_tree().quit(0)''')
s=s.replace('"/first-playable.png"','"/" + capture_kind + ".png"')
p.write_text(s)
print('Campaign gameplay integration written.')
