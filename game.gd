extends Node3D

const HELI = preload("res://assets/apache.glb")
const Campaign = preload("res://campaign.gd")
const Arena = preload("res://arena.gd")
const CombatAudio = preload("res://combat_audio.gd")
const HangarUI = preload("res://hangar_ui.gd")
const Radar = preload("res://radar.gd")
const FlightHUD = preload("res://flight_hud.gd")
const StartMenu = preload("res://start_menu.gd")
const VictoryScreen = preload("res://victory_screen.gd")
var victory_screen
var run_mode := "campaign"
var start_menu
var flight_hud
var using_pad := false
var active_pad := -1
var boost_energy := 100.0
var boosting := false
var flare_cooldown := 0.0
var hit_flash := 0.0
var damage_flash := 0.0
var reward_text := ""
var reward_timer := 0.0
var boost_overheated := false
var dust_timer := 0.0
var last_damage_direction := Vector3.ZERO
var kill_streak := 0
var streak_timer := 0.0
var cannon_flash := 0.0
var gun_flash: MeshInstance3D
var gun_light: OmniLight3D
var impact_position := Vector3.ZERO
var impact_damage := 0.0
var impact_timer := 0.0
var hit_overlay: StandardMaterial3D
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
var enemy_material: StandardMaterial3D
var craft: Node3D
var visual: Node3D
var camera: Camera3D
var rotor: Node3D
var tail_rotor: Node3D
var turret: Node3D
var muzzle: Node3D
var velocity := Vector3.ZERO
var heading := 0.0
var pitch := 0.03
var health := 100.0
var kills := 0
var wave := 1
var active := false
var paused := false
var elapsed := 0.0
var cannon_timer := 0.0
var rocket_timer := 0.0
var next_wave := 0.0
var shake := 0.0
var enemies: Array[Dictionary] = []
var hardpoints: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var target: Node3D
var aim_point := Vector3.ZERO
var sandstorm_timer := 18.0
var sandstorm_active := 0.0
var base_fog_density := 0.00032
var hud: Label
var status: Label
var crosshair: Label
var target_marker: Label
var radio_label: Label
var objective_label: Label
var help_label: Label
var radio_timer := 0.0
var rng := RandomNumberGenerator.new()
var smoke_test := false
var capture_test := false
var frame_count := 0
var screenshot_done := false
var projectile_hits := 0
var quitting := false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	rng.seed = 8801
	var args := OS.get_cmdline_user_args()
	smoke_test = "--smoke-test" in args
	for key in ["gameplay","menu","pause","alpine","volcanic","oasis","effects","title","cannon","victory"]:
		if ("--capture-"+key) in args or (key == "gameplay" and "--capture-test" in args):
			capture_test = true
			capture_kind = key
	if smoke_test or capture_test or "--audio-test" in args:
		profile.save_path = "user://qa-campaign.cfg"
	else:
		profile.load_profile()
		mission_index=clampi(profile.unlocked-1,0,Campaign.MISSIONS.size()-1)
	if capture_test:
		profile.unlocked = Campaign.MISSIONS.size()
		profile.xp = 1000
		profile.credits = 850
		if capture_kind == "alpine": mission_index = 1
		if capture_kind == "volcanic": mission_index = 2
		if capture_kind == "oasis": mission_index = 3
	audio = CombatAudio.new()
	add_child(audio)
	audio.setup(profile)
	if "--restore-audio" in args: audio.restore_audible()
	build_world()
	build_player()
	build_ui()
	if "--audio-test" in args:
		audio_test.call_deferred()
		return
	Input.joy_connection_changed.connect(func(device,connected):
		if not connected and device==active_pad:
			active_pad=-1
			using_pad=false
			if active: set_pause(true))
	if smoke_test:
		run_smoke_test.call_deferred()
	elif capture_test and capture_kind not in ["menu","title"]:
		start_game()
		if capture_kind == "pause": set_pause(true)
		if capture_kind == "victory":
			profile.completed.assign([0,1])
			mission_index=2
			kills=33
			elapsed=192
			finish_mission()
	elif not capture_test or capture_kind=="title":
		hangar.hide()
		start_menu.show()

func mat(color: Color, metal: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.65
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

func shape(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	o.mesh = mesh
	o.material_override = material
	parent.add_child(o)
	o.position = pos
	return o

func box(parent: Node3D, size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return shape(parent, m, mat(color), pos)

func ground_height(x: float, z: float) -> float:
	return arena.height_at(x,z) if is_instance_valid(arena) else 0.0

func build_world() -> void:
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
	arena = Arena.new()
	add_child(arena)
	arena.build(mission_index)
	loaded_mission = mission_index
	sandstorm_timer = 14.0 + mission_index * 2.0
	sandstorm_active = 0.0
	for child in arena.get_children():
		if child is WorldEnvironment and child.environment:
			base_fog_density = child.environment.fog_density
			break
	if enemy_material == null:
		enemy_material = mat(Color("8d9995"),.55)
		enemy_material.albedo_texture = load("res://assets/textures/metal_color.png")
		enemy_material.normal_enabled = true
		enemy_material.normal_texture = load("res://assets/textures/metal_normal.png")
		enemy_material.uv1_triplanar = true

func find_part(node: Node, prefix: String) -> Node3D:
	if str(node.name).begins_with(prefix) and node is Node3D:
		return node
	for child in node.get_children():
		var found := find_part(child, prefix)
		if found != null:
			return found
	return null

func build_player() -> void:
	craft = Node3D.new()
	add_child(craft)
	visual = Node3D.new()
	craft.add_child(visual)
	var model := HELI.instantiate()
	visual.add_child(model)
	model.rotation.y = PI
	model.position.y = -3.2
	rotor = find_part(model, "MAIN ROTOR")
	tail_rotor = find_part(model, "TAIL ROTOR")
	turret = find_part(model, "CHIN TURRET")
	muzzle = find_part(model, "Animated cannon muzzle flash")
	if muzzle != null:
		muzzle.visible = false
	camera = Camera3D.new()
	camera.fov = 66
	camera.far = 1600
	add_child(camera)
	craft.position = Vector3(0, ground_height(0,40)+42, 40)
	update_camera(1.0)
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius=.5
	flash_mesh.height=1
	gun_flash=shape(self,flash_mesh,mat(Color("ffe4a3"),0,4))
	gun_flash.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	gun_flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gun_flash.hide()
	gun_light=OmniLight3D.new()
	gun_light.omni_range=12
	gun_light.light_color=Color("ffd794")
	gun_light.light_energy=0
	add_child(gun_light)
	hit_overlay=mat(Color(1,.8,.35,.65),0,2)
	hit_overlay.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	hit_overlay.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED

func label_at(parent: Node, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	parent.add_child(l)
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root_ui := Control.new()
	canvas.add_child(root_ui)
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cockpit_panel := Panel.new()
	cockpit_panel.position = Vector2(16,12)
	cockpit_panel.size = Vector2(410,218)
	var cockpit_style := StyleBoxFlat.new()
	cockpit_style.bg_color = Color(0.015,0.04,0.055,0.86)
	cockpit_style.border_color = Color("41665e")
	cockpit_style.set_border_width_all(1)
	cockpit_style.set_corner_radius_all(8)
	cockpit_panel.add_theme_stylebox_override("panel",cockpit_style)
	root_ui.add_child(cockpit_panel)
	var heading_label := label_at(root_ui, Vector2(28,20),24,Color("ebd9a9"))
	heading_label.text = "APACHE / DUST FRONT"
	hud = label_at(root_ui,Vector2(28,58),17,Color("dfebe2"))
	status = label_at(root_ui,Vector2(28,190),16,Color("eebc6a"))
	crosshair = label_at(root_ui,Vector2.ZERO,28,Color("b6fbd6"))
	crosshair.text = "+"
	target_marker = label_at(root_ui,Vector2.ZERO,18,Color("ffbf72"))
	radio_label = label_at(root_ui,Vector2.ZERO,18,Color("f5dfaa"))
	radio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	radio_label.offset_top = 222
	radio_label.offset_bottom = 278
	radio_label.visible = false
	objective_label = label_at(root_ui,Vector2.ZERO,15,Color("b8e7d2"))
	objective_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	objective_label.offset_top = 282
	objective_label.offset_bottom = 313
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label = label_at(root_ui,Vector2.ZERO,14,Color("d0d8d4"))
	help_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help_label.offset_left = 28
	help_label.offset_top = -36
	help_label.text = "W/S speed · A/D strafe · Mouse aim · Space/C altitude · LMB cannon · RMB secondary · Esc pause"
	radar = Radar.new()
	root_ui.add_child(radar)
	radar.game = self
	radar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	radar.offset_left = -192
	radar.offset_top = 20
	radar.offset_right = -28
	radar.offset_bottom = 184
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The old labels retain the game state; the flight display renders it visually.
	for child in root_ui.get_children():
		if child != radar: child.hide()
	flight_hud = FlightHUD.new()
	flight_hud.game = self
	root_ui.add_child(flight_hud)
	flight_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flight_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hangar = HangarUI.new()
	root_ui.add_child(hangar)
	hangar.setup(self)
	hangar.open("hangar")
	start_menu=StartMenu.new()
	root_ui.add_child(start_menu)
	start_menu.setup(self)
	start_menu.hide()
	victory_screen=VictoryScreen.new()
	root_ui.add_child(victory_screen)
	victory_screen.setup(self)

func start_game(mode: String = "campaign") -> void:
	run_mode=mode
	victory_screen.hide()
	start_menu.hide()
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
	boost_energy = 100
	cannon_flash=0
	impact_timer=0
	gun_flash.hide()
	gun_light.light_energy=0
	boost_overheated=false
	kill_streak=0
	streak_timer=0
	flare_cooldown = 0
	hit_flash = 0
	damage_flash = 0
	reward_timer = 0
	sandstorm_active = 0.0
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
	var briefings: Array[String] = [
		"Command: Dust Front actual. Sweep the dune corridor and eliminate all hostiles. Stay above the terrain.",
		"Command: White Ridge actual. Interceptors are above the snow line. Keep your altitude and clear the patrol route.",
		"Command: Ember Coast actual. The armored ace is in the blockade. Break the escort, then bring the ace down.",
		"Command: Night Oasis actual. Black out the SAM ring, seize the waterpad, and clear the garrison."
	]
	var briefing: String = briefings[mission_index]
	radio_message(briefing, "OBJECTIVE  //  CLEAR WAVE 1 OF 3")
	update_camera(1.0)

func radio_message(message_text: String, objective_text: String = "") -> void:
	var key := "radio_wave"
	if objective_text.find("WAVE 1")>=0:
		key=["radio_briefing","radio_alpine","radio_volcanic","radio_briefing"][mission_index]
		if mission_index==0: message_text="Command: Dust Front actual. Sweep the corridor and eliminate all hostiles. Stay above the terrain."
	elif objective_text.find("OBJECTIVE COMPLETE")>=0:
		key="radio_complete"
	else:
		message_text="Wave inbound. Clear air contacts and hardpoints. Watch SAM pads and missile count."
	radio_label.text = "RADIO  //  COMMAND\n\"" + message_text + "\""
	radio_label.visible = true
	radio_timer = maxf(4,audio.speak(key)+.4)
	objective_label.text = objective_text

func clear_combat() -> void:
	if is_instance_valid(gun_flash): gun_flash.hide()
	if is_instance_valid(gun_light): gun_light.light_energy=0
	for array in [enemies,hardpoints,pickups,shots,effects]:
		for item in array:
			if is_instance_valid(item.node): item.node.queue_free()
		array.clear()
	target = null
	prior_lock = null

func return_to_hangar() -> void:
	victory_screen.hide()
	radio_timer=0
	active = false
	paused = false
	audio.flight(false)
	audio.set_pause(false)
	clear_combat()
	profile.save_profile()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hangar.open("hangar")

func return_to_start() -> void:
	return_to_hangar()
	hangar.hide()
	start_menu.show()

func set_pause(value: bool) -> void:
	paused = value
	audio.set_pause(value)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or smoke_test or capture_test else Input.MOUSE_MODE_CAPTURED
	if value:
		hangar.open("paused")
	else:
		hangar.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and absf(event.axis_value)>.25:
		active_pad=event.device
		using_pad=true
	if event is InputEventJoypadButton and event.pressed:
		active_pad=event.device
		using_pad=true
		if event.button_index==JOY_BUTTON_START and active:
			set_pause(not paused)
			get_viewport().set_input_as_handled()
		if event.button_index==JOY_BUTTON_Y and active and not paused: deploy_countermeasures()
	if event is InputEventKey or event is InputEventMouseButton:
		using_pad=false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and active:
			set_pause(not paused)
		elif event.keycode == KEY_R and active:
			start_game(run_mode)
		elif event.keycode == KEY_Q and active and not paused:
			deploy_countermeasures()
		elif event.keycode == KEY_M:
			profile.muted = not profile.muted
			audio.apply_levels()
			profile.save_profile()
	if active and not paused and event is InputEventMouseMotion:
		if event.relative.length()>1: using_pad=false
		heading -= event.relative.x * 0.0024 * profile.sensitivity
		pitch = clampf(pitch + event.relative.y * 0.0015 * profile.sensitivity, -0.55, 0.65)

func stick_curve(value: float, deadzone: float = .18) -> float:
	var scaled := maxf(0,(absf(value)-deadzone)/(1-deadzone))
	return signf(value)*scaled*scaled

func deploy_countermeasures() -> void:
	if not active or paused or flare_cooldown>0: return
	flare_cooldown=12
	for i in range(shots.size()-1,-1,-1):
		if shots[i].hostile and shots[i].node.position.distance_to(craft.position)<100:
			shots[i].node.queue_free()
			shots.remove_at(i)
	for i in range(16):
		puff(craft.position,craft.basis*Vector3(rng.randf_range(-18,18),-3,rng.randf_range(8,26)),.35,Color("ffda9c"),1.8)
	audio.cue("rocket")
	reward_text="DEFENSIVE BURST / AREA CLEARED"
	reward_timer=2

func spawn_wave() -> void:
	var count := 5 + wave * 2 + mission_index * 2
	if run_mode=="endless": count=mini(22,count)
	for i in range(count):
		var angle := float(i)/count*TAU
		var pos := craft.position + Vector3(sin(angle)*160,15+i*3,-150+cos(angle)*65)
		pos.y = maxf(pos.y,ground_height(pos.x,pos.z)+30)
		var kind := "scout"
		if i%3 == 1: kind = "interceptor"
		if i%4 == 3 and (wave > 1 or mission_index > 0): kind = "gunship"
		if wave%3 == 0 and i == 0: kind = "ace"
		spawn_enemy(pos,kind)
		if wave==1: enemies.back().cooldown+=7
	if wave >= 2 or mission_index >= 2:
		var sam_count := 1 + (1 if mission_index >= 3 or wave >= 3 else 0)
		for s in range(sam_count):
			var angle := PI * .2 + s * 1.1 + wave * .35
			var pos := Vector3(cos(angle)*140,0,sin(angle)*140+40)
			pos.y = ground_height(pos.x,pos.z)+2.5
			spawn_enemy(pos,"sam")
	spawn_hardpoints()
	missile_ammo = Campaign.SECONDARY[secondary_id].ammo
	audio.cue("reward")

func spawn_hardpoints() -> void:
	for item in hardpoints:
		if is_instance_valid(item.node): item.node.queue_free()
	hardpoints.clear()
	if not is_instance_valid(arena): return
	var sites: Array[Vector3] = arena.hardpoint_sites(wave)
	for i in range(sites.size()):
		var ground: Vector3 = sites[i]
		var node := Node3D.new()
		add_child(node)
		node.position = Vector3(ground.x, ground.y + 4.5, ground.z)
		var base := CylinderMesh.new()
		base.top_radius = 2.4
		base.bottom_radius = 3.2
		base.height = 3.5
		shape(node, base, enemy_material)
		var dish := SphereMesh.new()
		dish.radius = 2.1
		dish.height = 2.4
		shape(node, dish, mat(Color("6a7a72"), .4), Vector3(0, 3.2, 0))
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("ff7a4a")
		lamp.light_energy = 1.6
		lamp.omni_range = 18
		lamp.position = Vector3(0, 5.2, 0)
		node.add_child(lamp)
		var hp := 160.0 + wave * 35.0 + mission_index * 20.0
		hardpoints.append({"node": node, "kind": "hardpoint", "hp": hp, "max_hp": hp, "radius": 5.5, "hit_time": 0.0})

func spawn_enemy(pos: Vector3, kind: String = "scout") -> void:
	var enemy := Node3D.new()
	add_child(enemy)
	enemy.position = pos
	var spinners: Array[Node3D] = []
	if kind == "sam":
		var pedestal := CylinderMesh.new()
		pedestal.top_radius = 1.4
		pedestal.bottom_radius = 2.2
		pedestal.height = 4.0
		shape(enemy, pedestal, enemy_material)
		var turret_box := box(enemy, Vector3(2.4, 1.2, 2.4), Color("4d5652"), Vector3(0, 2.6, 0))
		spinners.append(turret_box)
		for side in [-1.0, 1.0]:
			box(enemy, Vector3(.45, .45, 3.4), Color("2f3431"), Vector3(side * .7, 3.1, -1.2))
		var lens := SphereMesh.new()
		lens.radius = .28
		lens.height = .56
		shape(enemy, lens, mat(Color("ff5034"), 0, 3), Vector3(0, 3.4, -1.6))
		var hp_sam: float = 180.0 * (1 + mission_index * .15)
		if run_mode == "endless": hp_sam *= minf(2.5, 1 + (wave - 1) * .08)
		enemies.append({"node": enemy, "kind": kind, "hp": hp_sam, "max_hp": hp_sam, "radius": 4.0, "cooldown": rng.randf_range(2.5, 4.5), "phase": rng.randf() * TAU, "spinners": spinners, "velocity": Vector3.ZERO, "grounded": true})
		return
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
	if run_mode=="endless": hp*=minf(2.5,1+(wave-1)*.08)
	enemies.append({"node":enemy,"kind":kind,"hp":hp,"max_hp":hp,"radius":5.5 if kind == "ace" else 4.2 if kind == "gunship" else 3.0,"cooldown":rng.randf_range(3,6),"phase":rng.randf()*TAU,"spinners":spinners,"velocity":Vector3.ZERO,"grounded":false})

func _physics_process(delta: float) -> void:
	if capture_test and screenshot_done: return
	frame_count += 1
	if smoke_test:
		return
	if active and not paused:
		update_game(delta)
	elif not active:
		if rotor != null:
			rotor.rotate_y(delta * 4)
	update_hud()
	if capture_test and frame_count > 35 and not screenshot_done:
		screenshot_done = true
		if capture_kind=="cannon":
			fire(false)
			update_shots(.08)
			if not enemies.is_empty(): damage_enemy(enemies[0],12)
		if capture_kind=="effects":
			burst(craft.position+Vector3(10,8,-40),5)
			update_effects(.16)
			hit_flash=.15
			damage_flash=.35
			last_damage_direction=Vector3.RIGHT
		capture_frame.call_deferred()

func update_game(delta: float) -> void:
	elapsed += delta
	cannon_flash=maxf(0,cannon_flash-delta)
	impact_timer=maxf(0,impact_timer-delta)
	streak_timer=maxf(0,streak_timer-delta)
	if streak_timer<=0: kill_streak=0
	hit_flash=maxf(0,hit_flash-delta)
	damage_flash=maxf(0,damage_flash-delta)
	reward_timer=maxf(0,reward_timer-delta)
	flare_cooldown=maxf(0,flare_cooldown-delta)
	cannon_timer = maxf(0, cannon_timer - delta)
	rocket_timer = maxf(0, rocket_timer - delta)
	shake = maxf(0, shake - delta * 2)
	craft.rotation.y = heading
	var forward := -craft.basis.z
	var right := craft.basis.x
	var throttle := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var strafe := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var climb := float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_C))
	var controller := Input.get_connected_joypads()
	if using_pad and active_pad in controller:
		var pad := active_pad
		var stick_x := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		var stick_y := Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)
		strafe = stick_curve(stick_x)
		throttle = -stick_curve(stick_y)
		var aim_x := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X)
		var aim_y := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)
		heading -= stick_curve(aim_x) * delta * 1.7 * profile.sensitivity
		pitch = clampf(pitch + stick_curve(aim_y) * delta * profile.sensitivity, -0.55, 0.65)
		climb = float(Input.is_joy_button_pressed(pad, JOY_BUTTON_A)) - float(Input.is_joy_button_pressed(pad, JOY_BUTTON_B))
	craft.rotation.y=heading
	forward=-craft.basis.z
	right=craft.basis.x
	var boost_pressed := Input.is_physical_key_pressed(KEY_SHIFT)
	if using_pad and active_pad in controller: boost_pressed=Input.is_joy_button_pressed(active_pad,JOY_BUTTON_X)
	if boost_overheated and boost_energy>=25: boost_overheated=false
	boosting=boost_pressed and not boost_overheated and boost_energy>0 and absf(throttle)>.1
	boost_energy=clampf(boost_energy+(-30 if boosting else 17)*delta,0,100)
	if boost_energy<=0: boost_overheated=true
	velocity = velocity.lerp(forward * throttle * profile.speed() * (1.65 if boosting else 1.0) + right * strafe * 34 + Vector3.UP * climb * 26, 1 - exp(-delta * 2.1))
	camera.fov=lerpf(camera.fov,74 if boosting else 66,1-exp(-delta*3))
	craft.position += velocity * delta
	craft.position.x = clampf(craft.position.x, -Arena.LIMIT, Arena.LIMIT)
	craft.position.z = clampf(craft.position.z, -Arena.LIMIT, Arena.LIMIT)
	craft.position.y = minf(craft.position.y, 380)
	var floor_y := ground_height(craft.position.x, craft.position.z) + 3.4
	if craft.position.y < floor_y:
		craft.position.y = floor_y
		take_damage(delta * 25)
		velocity.y = maxf(velocity.y, 0)
	visual.rotation.z = lerp_angle(visual.rotation.z, -strafe * 0.24, delta * 4)
	visual.rotation.x = lerp_angle(visual.rotation.x, -throttle * 0.12, delta * 4)
	rotor.rotate_y(delta * 38)
	tail_rotor.rotate_x(delta * 57)
	audio.update_flight(velocity.length(),delta)
	dust_timer-=delta
	var agl := craft.position.y-ground_height(craft.position.x,craft.position.z)
	if dust_timer<=0 and agl<22:
		dust_timer=.09
		var dust_color: Color = [Color("b9a27b"),Color("d9e7ed"),Color("82726b"),Color("6d7a8c")][mission_index]
		var offset := Vector3(rng.randf_range(-7,7),0,rng.randf_range(-7,7))
		var position_on_ground := craft.position+offset
		position_on_ground.y=ground_height(position_on_ground.x,position_on_ground.z)+.6
		puff(position_on_ground,offset.normalized()*7+Vector3.UP,1.0,dust_color,1.3)
	update_sandstorm(delta)
	update_camera(delta)
	find_target()
	if turret != null and turret.global_position.distance_to(aim_point) > 1:
		turret.look_at(aim_point, Vector3.UP, true)
	var cannon_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var secondary_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if using_pad and active_pad in controller:
		cannon_pressed = Input.is_joy_button_pressed(active_pad, JOY_BUTTON_RIGHT_SHOULDER) or Input.get_joy_axis(active_pad,JOY_AXIS_TRIGGER_RIGHT)>.3
		secondary_pressed = Input.is_joy_button_pressed(active_pad, JOY_BUTTON_LEFT_SHOULDER) or Input.get_joy_axis(active_pad,JOY_AXIS_TRIGGER_LEFT)>.3
	if cannon_pressed and cannon_timer <= 0:
		fire(false)
	if secondary_pressed and rocket_timer <= 0 and missile_ammo > 0:
		fire(true)
	if muzzle != null:
		muzzle.visible = false
	gun_flash.visible=cannon_flash>0
	gun_light.light_energy=2.5 if cannon_flash>0 else 0
	update_enemies(delta)
	update_shots(delta)
	update_pickups(delta)
	update_hardpoint_flash(delta)
	update_effects(delta)
	if enemies.is_empty() and hardpoints.is_empty():
		next_wave += delta
		if next_wave > 4.0:
			next_wave = 0
			if wave >= 3 and run_mode=="campaign":
				finish_mission()
			else:
				wave += 1
				health = minf(profile.max_health(), health + 25)
				spawn_wave()
				radio_message("Wave %d inbound. Clear air contacts and hardpoints." % wave, "OBJECTIVE  //  CLEAR WAVE %d OF 3" % wave)
	warning_timer = maxf(0,warning_timer-delta)
	if health < profile.max_health()*.25 and warning_timer <= 0:
		warning_timer = 3.0
		audio.cue("warning")

func update_sandstorm(delta: float) -> void:
	if mission_index not in [0, 3]:
		sandstorm_active = 0.0
		return
	if sandstorm_active > 0:
		sandstorm_active = maxf(0, sandstorm_active - delta)
		if sandstorm_active <= 0:
			_set_fog_density(base_fog_density)
		elif int(sandstorm_active * 8) % 2 == 0:
			var dust := Color("b9a27b") if mission_index == 0 else Color("6d7a8c")
			puff(craft.position + Vector3(rng.randf_range(-40, 40), rng.randf_range(2, 18), rng.randf_range(-40, 40)), Vector3(rng.randf_range(-12, 12), 1, rng.randf_range(-12, 12)), 1.4, dust, 1.6)
	else:
		sandstorm_timer -= delta
		if sandstorm_timer <= 0:
			sandstorm_timer = rng.randf_range(22, 36)
			sandstorm_active = rng.randf_range(6, 10)
			_set_fog_density(base_fog_density * 3.4)
			reward_text = "SANDSTORM  /  VISIBILITY DROP"
			reward_timer = 2.2
			audio.cue("warning")

func _set_fog_density(value: float) -> void:
	if not is_instance_valid(arena): return
	for child in arena.get_children():
		if child is WorldEnvironment and child.environment:
			child.environment.fog_density = value
			return

func update_hardpoint_flash(delta: float) -> void:
	for h in hardpoints:
		if h.get("hit_time", 0.0) > 0:
			h.hit_time = maxf(0, h.hit_time - delta)
			if h.hit_time <= 0:
				for mesh in h.node.find_children("*", "MeshInstance3D", true, false):
					mesh.material_overlay = null

func update_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var p := pickups[i]
		p.life -= delta
		p.node.rotate_y(delta * 2.4)
		p.node.position.y = ground_height(p.node.position.x, p.node.position.z) + 3.0 + sin(elapsed * 3 + p.phase) * .4
		var flat := Vector2(craft.position.x - p.node.position.x, craft.position.z - p.node.position.z)
		if flat.length() < 12.0 and absf(craft.position.y - p.node.position.y) < 40.0:
			if p.kind == "hull":
				health = minf(profile.max_health(), health + 28)
				reward_text = "HULL PATCH  /  +28"
			else:
				missile_ammo = mini(Campaign.SECONDARY[secondary_id].ammo, missile_ammo + 6)
				reward_text = "AMMO CRATE  /  +6"
			reward_timer = 2.0
			audio.cue("reward")
			p.node.queue_free()
			pickups.remove_at(i)
			continue
		if p.life <= 0:
			p.node.queue_free()
			pickups.remove_at(i)

func update_camera(delta: float) -> void:
	var offset := craft.basis * Vector3(0, 8 + pitch * 8, 22)
	var desired := craft.position + offset
	camera.position = camera.position.lerp(desired, 1 - exp(-delta * 6)) if delta < 0.5 else desired
	var focus := craft.position - craft.basis.z * 32 + Vector3.UP * (3 - pitch * 42)
	camera.look_at(focus)
	if shake > 0:
		camera.h_offset = rng.randf_range(-shake, shake) * 0.25 * profile.camera_shake
		camera.v_offset = rng.randf_range(-shake, shake) * 0.2 * profile.camera_shake
	else:
		camera.h_offset = 0
		camera.v_offset = 0

func find_target() -> void:
	target = null
	var ray := -camera.global_basis.z
	var best := 0.97
	aim_point = camera.position + ray * 600
	for e in enemies:
		var direction: Vector3 = (e.node.position - camera.position).normalized()
		var dot := ray.dot(direction)
		if dot > best and craft.position.distance_to(e.node.position) < 550:
			best = dot
			target = e.node
	for h in hardpoints:
		var direction: Vector3 = (h.node.position - camera.position).normalized()
		var dot := ray.dot(direction)
		if dot > best and craft.position.distance_to(h.node.position) < 550:
			best = dot
			target = h.node
	if is_instance_valid(target):
		aim_point = target.position
		for enemy in enemies:
			if enemy.node==target:
				aim_point+=enemy.velocity*minf(craft.position.distance_to(target.position)/280,1.5)
	if is_instance_valid(target) and target != prior_lock:
		audio.cue("lock")
	prior_lock = target

func fire(rocket: bool) -> void:
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
		audio.fire_cannon(primary_id)
		cannon_flash=.045
		gun_flash.position=origin+direction*2.4
		gun_flash.look_at(origin+direction*20)
		gun_flash.scale=Vector3(.8,.8,3.2 if primary_id==2 else 2.3)
		gun_flash.show()
		gun_light.position=origin
		gun_light.light_energy=2.5
		visual.rotation.x-=.012 if primary_id!=2 else .025
		shake = .12

func spawn_shot(origin: Vector3, direction: Vector3, hostile: bool, rocket: bool, homing: Node3D = null) -> void:
	var tracer := BoxMesh.new()
	tracer.size = Vector3(.24,.24,5.5) if not rocket and not hostile else Vector3(.13,.13,2.4) if hostile else Vector3(.32,.32,1.8)
	var color := Color("ff573f") if hostile else Color("ffd58b")
	var node := shape(self, tracer, mat(color, 0, 4), origin)
	if direction.length() > 0.1:
		node.look_at(origin + direction)
	shots.append({"node": node, "velocity": direction * (95.0 if hostile else (120.0 if rocket else 280.0)), "ttl": 5.0, "hostile": hostile, "rocket": rocket, "target": homing, "trail": 0.0, "damage": 9.0 if hostile else 110.0 if rocket else 25.0, "splash": 3.0 if rocket else 0.0})

func update_enemies(delta: float) -> void:
	for e in enemies:
		var node: Node3D = e.node
		if e.get("hit_time",0.0)>0:
			e.hit_time=maxf(0,e.hit_time-delta)
			if e.hit_time<=0:
				for mesh in node.find_children("*","MeshInstance3D",true,false): mesh.material_overlay=null
		var toward: Vector3 = craft.position-node.position
		var distance := toward.length()
		var direction := toward.normalized()
		if e.get("grounded", false) or e.kind == "sam":
			node.position.y = ground_height(node.position.x, node.position.z) + 2.5
			e.velocity = Vector3.ZERO
			if distance > .1:
				var flat := Vector3(toward.x, 0, toward.z)
				if flat.length() > .1:
					var desired_basis := Basis.looking_at(flat.normalized())
					node.quaternion = node.quaternion.slerp(desired_basis.get_rotation_quaternion(), minf(delta * 2.5, 1))
			for spinner in e.spinners:
				spinner.rotate_y(delta * 1.8)
			e.cooldown -= delta
			if e.cooldown <= 0 and distance < 420:
				e.cooldown = rng.randf_range(2.2, 3.6)
				var predicted := craft.position + velocity * minf(distance / 90, .8)
				var aim := (predicted - node.position).normalized()
				spawn_shot(node.position + Vector3.UP * 3.2, aim, true, true)
				shots.back().damage = 16.0
				shots.back().velocity = aim * 85.0
				play_sound("heavy", node.position, -14)
			continue
		var tangent := direction.cross(Vector3.UP).normalized()
		var speed: float = {"scout":20.0,"interceptor":45.0,"gunship":13.0,"ace":18.0}.get(e.kind, 20.0)
		var desired := direction*(1.0 if distance > 120 else -.25)+tangent*.8
		var orbit_sign := 1.0 if sin(e.phase)>0 else -1.0
		desired = direction*(1.0 if distance>170 else -.3)+tangent*orbit_sign
		if e.kind == "interceptor":
			var attack_pass := fmod(elapsed+e.phase*2,9)<4.5
			desired = direction*(1.25 if attack_pass and distance>65 else -.9)+tangent*.85*orbit_sign
		elif e.kind in ["gunship","ace"]:
			desired=direction*(.8 if distance>230 else -.25)+tangent*.7*orbit_sign
		desired.y+=sin(elapsed*.8+e.phase)*.3
		var separation := Vector3.ZERO
		for other in enemies:
			if other.node==node: continue
			var away: Vector3 = node.position-other.node.position
			if away.length_squared()<625 and away.length_squared()>.1: separation+=away.normalized()*(1-away.length()/25)
		e.velocity=e.velocity.lerp(desired.normalized()*speed+separation*20,1-exp(-delta*1.8))
		node.position += e.velocity*delta
		node.position.y = maxf(node.position.y,ground_height(node.position.x,node.position.z)+18)
		node.position.x = clampf(node.position.x,-1200,1200)
		node.position.z = clampf(node.position.z,-1200,1200)
		if distance > .1:
			var look_direction: Vector3 = e.velocity if e.kind=="interceptor" else toward
			if look_direction.length()>.1:
				var desired_basis := Basis.looking_at(look_direction.normalized())
				node.quaternion=node.quaternion.slerp(desired_basis.get_rotation_quaternion(),minf(delta*3,1))
		if e.kind=="interceptor": node.rotation.z=lerp_angle(node.rotation.z,-orbit_sign*.3,delta*2)
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
			take_damage(delta*20)

func segment_distance(a: Vector3, b: Vector3, point: Vector3) -> float:
	var d := b - a
	var t := clampf((point - a).dot(d) / maxf(d.length_squared(), 0.00001), 0, 1)
	return (a + d * t).distance_to(point)

func update_shots(delta: float) -> void:
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
				last_damage_direction=-b.velocity.normalized()
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
					for h in hardpoints:
						if h.node.position.distance_to(impact) < b.splash:
							damage_hardpoint(h, b.damage * .65)
				for e in victims:
					damage_enemy(e,b.damage if e == victim else b.damage*.65)
				burst(impact,1.7 if b.rocket else .7)
				hit = true
			else:
				for h in hardpoints:
					if segment_distance(previous, node.position, h.node.position) < h.radius:
						projectile_hits += 1
						damage_hardpoint(h, b.damage)
						burst(h.node.position, 1.4 if b.rocket else .8)
						hit = true
						break
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

func damage_hardpoint(site: Dictionary, damage: float) -> void:
	if site not in hardpoints: return
	hit_flash = .22
	impact_timer = .45
	impact_position = site.node.position
	impact_damage = damage
	audio.confirm_hit()
	for mesh in site.node.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = hit_overlay
	site["hit_time"] = .09
	site.hp -= damage
	if site.hp <= 0:
		var pos: Vector3 = site.node.position
		burst(pos, 5)
		play_sound("heavy_explosion", pos, -2)
		site.node.queue_free()
		hardpoints.erase(site)
		kills += 1
		kill_streak += 1
		streak_timer = 6
		var old_xp: int = profile.xp
		var old_credits: int = profile.credits
		profile.earn_kill("hardpoint")
		reward_text = "HARDPOINT  /  +%d XP  +%d CR" % [profile.xp - old_xp, profile.credits - old_credits]
		reward_timer = 2.5
		apply_streak_bonus()

func spawn_pickup(pos: Vector3, kind: String) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = pos
	var crate := BoxMesh.new()
	crate.size = Vector3(1.6, 1.2, 1.6)
	var color := Color("6fd0a0") if kind == "hull" else Color("efbb7c")
	shape(node, crate, mat(color, .2, 1.2))
	pickups.append({"node": node, "kind": kind, "life": 22.0, "phase": rng.randf() * TAU})

func apply_streak_bonus() -> void:
	if kill_streak == 3:
		profile.credits += 25
		missile_ammo = mini(Campaign.SECONDARY[secondary_id].ammo, missile_ammo + 2)
		reward_text = "STREAK 3  /  +25 CR  +2 AMMO"
		reward_timer = 2.8
		audio.cue("reward")
		profile.save_profile()
	elif kill_streak == 5:
		health = minf(profile.max_health(), health + 20)
		profile.credits += 45
		reward_text = "STREAK 5  /  +20 HULL  +45 CR"
		reward_timer = 2.8
		audio.cue("reward")
		profile.save_profile()
	elif kill_streak == 8:
		missile_ammo = Campaign.SECONDARY[secondary_id].ammo
		profile.credits += 80
		reward_text = "STREAK 8  /  FULL RELOAD  +80 CR"
		reward_timer = 3.0
		audio.cue("reward")
		profile.save_profile()

func damage_enemy(enemy: Dictionary, damage: float) -> void:
	if enemy not in enemies: return
	hit_flash=.22
	impact_timer=.45
	impact_position=enemy.node.position
	impact_damage=damage
	audio.confirm_hit()
	for mesh in enemy.node.find_children("*","MeshInstance3D",true,false): mesh.material_overlay=hit_overlay
	enemy["hit_time"]=.09
	enemy.hp -= damage
	if enemy.hp <= 0:
		var pos: Vector3 = enemy.node.position
		burst(pos,6 if enemy.kind == "ace" else 4)
		play_sound("heavy_explosion" if enemy.kind in ["gunship","ace","sam"] else "explosion",pos,-3)
		if enemy.kind in ["gunship", "ace"] and rng.randf() < .55:
			spawn_pickup(pos, "hull" if rng.randf() < .5 else "ammo")
		elif enemy.kind == "sam" and rng.randf() < .35:
			spawn_pickup(pos, "ammo")
		enemy.node.queue_free()
		enemies.erase(enemy)
		kills += 1
		kill_streak+=1
		streak_timer=6
		var old_rank: int = profile.rank()
		var old_xp: int = profile.xp
		var old_credits: int = profile.credits
		profile.earn_kill(enemy.kind)
		reward_text="%s  /  +%d XP  +%d CR" % [enemy.kind.to_upper(),profile.xp-old_xp,profile.credits-old_credits]
		if kill_streak>1: reward_text="%d CHAIN  /  " % kill_streak+reward_text
		reward_timer=2.5
		if profile.rank() > old_rank: audio.cue("reward")
		apply_streak_bonus()

func puff(pos: Vector3, drift: Vector3, size: float, color: Color, life: float) -> void:
	if effects.size() > 220:
		return
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2
	sphere.radial_segments = 8
	sphere.rings = 4
	var node := shape(self, sphere, mat(color, 0, 1.0 if color.r > 0.9 else 0.0), pos)
	node.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effects.append({"node": node, "velocity": drift, "life": life, "total": life})

func burst(pos: Vector3, power: float) -> void:
	if power>=3 and effects.size()<210:
		var ring := TorusMesh.new()
		ring.inner_radius=.9
		ring.outer_radius=1.0
		var shock_material := mat(Color("ffdc9a"),0,2)
		shock_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		shock_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		var shock := shape(self,ring,shock_material,pos)
		if shock.global_position.distance_squared_to(camera.global_position)>.01:
			shock.look_at(camera.global_position)
			shock.rotate_object_local(Vector3.RIGHT,PI/2)
		shock.scale=Vector3.ONE*power
		shock.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effects.append({"node":shock,"velocity":Vector3.ZERO,"life":.55,"total":.55,"shock":true})
	for i in range(10):
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 1), rng.randf_range(-1, 1)) * power * 4
		puff(pos, v, power * rng.randf_range(0.12, 0.3), Color("ff9a35") if i < 5 else Color("514b46"), rng.randf_range(0.3, 0.9))

func update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var e := effects[i]
		e.life -= delta
		e.node.position += e.velocity * delta
		e.node.scale *= 1 + delta * (5 if e.get("shock",false) else 1.2)
		var material: StandardMaterial3D = e.node.material_override
		material.albedo_color.a=clampf(e.life/e.total,0,1)
		if material.emission_enabled: material.emission_energy_multiplier=maxf(0,e.life/e.total)
		if e.life <= 0:
			e.node.queue_free()
			effects.remove_at(i)

func play_sound(sound_name: String, pos: Vector3, volume: float) -> void:
	audio.play_at(sound_name,pos,volume)

func take_damage(amount: float) -> void:
	if not active: return
	damage_flash=.7
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
	if not active or run_mode!="campaign": return
	active = false
	paused = false
	audio.flight(false)
	var reward: int = profile.complete_mission(mission_index)
	total_reward = reward
	audio.cue("reward")
	radio_message("Command to Apache. Mission complete. Return to base for resupply and upgrades.", "OBJECTIVE COMPLETE  //  RETURN TO HANGAR")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var note := "%s cleared / %d kills / +%d credits. Choose your next sortie below." % [Campaign.MISSIONS[mission_index].name,kills,reward]
	note += "\nCOMMAND: Mission complete. Return to base for resupply and upgrades."
	var cleared_index := mission_index
	mission_index = mini(mission_index+1,Campaign.MISSIONS.size()-1)
	hangar.hide()
	victory_screen.celebrate(cleared_index,reward)
	audio.celebrate()

func update_hud() -> void:
	flight_hud.queue_redraw()
	radar.visible=active and not paused
	if help_label != null:
		help_label.text = "L stick fly · R stick aim · A/B altitude · RB cannon · LB secondary · Start pause" if not Input.get_connected_joypads().is_empty() else "W/S speed · A/D strafe · Mouse aim · Space/C altitude · LMB cannon · RMB secondary · Esc pause"
	if not paused: radio_timer = maxf(0.0, radio_timer - get_process_delta_time())
	if radio_timer <= 0.0:
		radio_label.visible = false
	var viewport_size := get_viewport().get_visible_rect().size
	crosshair.position = viewport_size/2-Vector2(9,19)
	hud.text = "HULL %03d / %03d   WAVE %d/3   KILLS %02d\nSPEED %03d km/h   AGL %03d m   RANK %d\nPRIMARY  %s\nSECONDARY %02d  %s  %s\n%s" % [int(health),int(profile.max_health()),wave,kills,int(velocity.length()*3.6),int(craft.position.y-ground_height(craft.position.x,craft.position.z)),profile.rank(),Campaign.PRIMARY[primary_id].name,missile_ammo,"READY" if rocket_timer <= 0 else "%.1fs" % rocket_timer,Campaign.SECONDARY[secondary_id].name,Campaign.MISSIONS[loaded_mission].name]
	status.text = "%d HOSTILES / %d HARDPOINTS / %s" % [enemies.size(),hardpoints.size(),"TARGET LOCK" if is_instance_valid(target) else "SEARCHING"]
	if active and enemies.is_empty() and hardpoints.is_empty(): status.text = "OPERATION CLEAR" if wave == 3 else "RESUPPLY / NEXT WAVE IN %d" % maxi(1,int(5-next_wave))
	if active and craft.position.y-ground_height(craft.position.x,craft.position.z) < 10: status.text += " / TERRAIN — CLIMB"
	if abs(craft.position.x)>1120 or abs(craft.position.z)>1120: status.text += " / ARENA BOUNDARY"
	if not profile.last_error.is_empty(): status.text = profile.last_error
	target_marker.visible = active and is_instance_valid(target) and not target.is_queued_for_deletion() and not camera.is_position_behind(target.position)
	if target_marker.visible:
		target_marker.text = "[ LOCK ]"
		for e in enemies:
			if e.node == target: target_marker.text = "[ %s %d%% ]" % [e.kind.to_upper(),int(e.hp/e.max_hp*100)]
		for h in hardpoints:
			if h.node == target: target_marker.text = "[ HARDPOINT %d%% ]" % int(h.hp/h.max_hp*100)
		target_marker.position = camera.unproject_position(target.position)-Vector2(60,30)
	radar.queue_redraw()
	for label in [hud,status,crosshair,target_marker,radio_label,objective_label,help_label]: label.hide()

func run_smoke_test() -> void:
	start_game()
	update_hud()
	profile.sensitivity=1.25
	profile.camera_shake=.4
	profile.save_profile()
	var settings_check=Campaign.new()
	settings_check.save_path=profile.save_path
	settings_check.load_profile()
	assert(settings_check.sensitivity==1.25 and is_equal_approx(settings_check.camera_shake,.4),"Flight settings failed to persist")
	puff(craft.position,Vector3.ZERO,1,Color.GRAY,1)
	update_effects(.25)
	assert(is_equal_approx(effects.back().node.material_override.albedo_color.a,.75),"VFX fade failed")
	update_effects(1)
	assert(effects.is_empty(),"Expired VFX were not removed")
	assert(stick_curve(.1)==0 and is_equal_approx(stick_curve(1),1),"Stick deadzone/curve failed")
	var pad_event := InputEventJoypadButton.new()
	pad_event.device=77
	pad_event.button_index=JOY_BUTTON_START
	pad_event.pressed=true
	_unhandled_input(pad_event)
	assert(paused and using_pad,"Controller Start failed to pause")
	_unhandled_input(pad_event)
	assert(not paused,"Controller Start failed to resume")
	Input.joy_connection_changed.emit(77,false)
	assert(paused and not using_pad,"Controller disconnect did not pause safely")
	set_pause(false)
	spawn_shot(craft.position+Vector3(0,0,20),Vector3.FORWARD,true,false)
	deploy_countermeasures()
	assert(shots.is_empty() and flare_cooldown==12,"Defensive burst failed")
	var effect_count := effects.size()
	deploy_countermeasures()
	assert(effects.size()==effect_count,"Defensive burst ignored cooldown")
	start_game()
	assert(rotor != null and tail_rotor != null and turret != null)
	assert(enemies.size() == 7,"Expanded wave did not spawn")
	assert(hardpoints.size() >= 1,"Hardpoints did not spawn")
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
	assert(hardpoints.size() >= 1,"Hardpoints did not spawn")
	for enemy in enemies: enemy.node.queue_free()
	enemies.clear()
	var site: Dictionary = hardpoints[0]
	for i in range(hardpoints.size()-1,-1,-1):
		if hardpoints[i] != site:
			hardpoints[i].node.queue_free()
			hardpoints.remove_at(i)
	site.node.position = Vector3(400,100,400)
	site.hp = 30
	var shot_dir: Vector3 = (site.node.position - Vector3(400,100,360)).normalized()
	spawn_shot(Vector3(400,100,360),shot_dir,false,false)
	shots.back().damage = 80
	update_shots(.2)
	assert(hardpoints.is_empty() and kills >= 1,"Hardpoint destruction failed")
	kill_streak = 3
	streak_timer = 6
	var streak_credits: int = profile.credits
	var streak_ammo: int = missile_ammo
	apply_streak_bonus()
	assert(profile.credits == streak_credits + 25 and missile_ammo == mini(Campaign.SECONDARY[secondary_id].ammo, streak_ammo + 2),"Streak bonus failed")
	spawn_pickup(craft.position + Vector3(0, 0, 2), "hull")
	health = minf(health, profile.max_health() - 40)
	var hull_before: float = health
	update_pickups(.05)
	assert(health > hull_before and pickups.is_empty(),"Pickup collection failed")
	aim_point = craft.position+Vector3(0,0,-100)
	var before := shots.size()
	fire(true)
	assert(shots.size() == before+3 and missile_ammo == 27,"Salvo/ammunition failed")
	for b in shots: assert(b.damage == 65,"Loadout damage failed")
	for enemy in enemies: enemy.node.queue_free()
	enemies.clear()
	for h in hardpoints: h.node.queue_free()
	hardpoints.clear()
	next_wave = 4.0
	update_game(1.0/60)
	assert(wave == 2 and enemies.size() >= 9 and missile_ammo == 30,"Wave/resupply failed")
	assert(enemies.any(func(item): return item.kind == "sam"),"SAM pads did not spawn on wave 2")
	set_pause(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var center: Vector2 = hangar.panel.get_global_rect().get_center()
	assert(center.distance_to(get_viewport().get_visible_rect().size/2)<2,"Pause panel is not centered")
	set_pause(false)
	wave = 3
	for enemy in enemies: enemy.node.queue_free()
	enemies.clear()
	for h in hardpoints: h.node.queue_free()
	hardpoints.clear()
	next_wave = 4.0
	update_game(1.0/60)
	assert(not active and profile.unlocked == 2 and 0 in profile.completed,"Mission unlock failed")
	assert(victory_screen.visible and audio.victory_music.playing,"Victory celebration did not start")
	var cleared_balance: int = profile.credits
	finish_mission()
	assert(profile.credits==cleared_balance,"Victory awarded duplicate rewards")
	var restored = Campaign.new()
	restored.save_path = profile.save_path
	restored.load_profile()
	assert(restored.xp == profile.xp and restored.credits == profile.credits and restored.armor == 1 and restored.secondary == 1,"Save/load failed")
	for index in [1,2,3]:
		profile.unlocked = Campaign.MISSIONS.size()
		mission_index = index
		start_game()
		assert(arena.biome == index)
		assert(enemies.size() >= 5 + wave * 2 + index * 2)
		if index >= 2:
			assert(enemies.any(func(item): return item.kind == "sam"),"Expected SAM on later theaters")
		for i in range(60): update_game(1.0/60)
	assert(sandstorm_timer < 40,"Sandstorm timer missing on oasis")
	set_pause(true)
	return_to_hangar()
	assert(not active and not paused and hangar.visible,"Hangar transition failed")
	start_game()
	take_damage(500)
	assert(not active and hangar.visible,"Game over failed")
	start_game()
	assert(health == 125 and kills == 0,"Restart failed")
	primary_id=1
	aim_point=craft.position+Vector3(0,0,-100)
	fire(false)
	assert(gun_flash.visible and cannon_flash>0,"Rapid cannon has no muzzle flash")
	assert(audio.cannon_voice_index>0,"Cannon audio pool did not play")
	var flashed: Dictionary = enemies[0]
	damage_enemy(flashed,1)
	assert(impact_damage==1 and impact_timer>0,"Hit feedback did not trigger")
	update_enemies(.12)
	for mesh in flashed.node.find_children("*","MeshInstance3D",true,false):
		assert(mesh.material_overlay==null,"Target hit flash did not clear")
	update_hud()
	for key in ["radio_briefing","radio_wave","radio_alpine","radio_volcanic","radio_complete"]:
		assert(audio.streams.has(key) and audio.streams[key]!=null,"Missing radio recording: "+key)
	mission_index=2
	start_game()
	assert(audio.radio.stream==audio.streams.radio_volcanic,"Wrong briefing for volcanic mission")
	set_pause(true)
	assert(audio.radio.stream_paused,"Radio does not pause with gameplay")
	set_pause(false)
	return_to_hangar()
	assert(not audio.radio.playing,"Radio persisted after returning to hangar")
	start_game("endless")
	wave=3
	clear_combat()
	next_wave=4.1
	var endless_balance: int = profile.credits
	update_game(1.0/60)
	assert(active and wave==4 and not victory_screen.visible,"Endless mode stopped at campaign end")
	assert(profile.credits==endless_balance,"Endless awarded campaign-clear bonus")
	clear_combat()
	wave=90
	spawn_wave()
	assert(enemies.size()>=22,"Endless air cap failed")
	assert(enemies.any(func(item): return item.kind=="ace"),"Endless ace cadence failed")
	start_game()
	assert(run_mode=="campaign" and wave==1,"Campaign did not reset after endless")
	DirAccess.remove_absolute(profile.save_path)
	print("SMOKE PASS: combat, hardpoints, SAM, pickups, streaks, sandstorm, homing, salvo/ammo, rewards, upgrade gating, loadouts, centered pause, resupply, mission unlock, save/load, all biomes, defeat and restart")
	await quit_game()

func audio_test() -> void:
	var capture := AudioEffectCapture.new()
	capture.buffer_length=3
	AudioServer.add_bus_effect(0,capture)
	await get_tree().create_timer(1.5).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for frame in frames: peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	assert(peak>.001,"Menu music produced no audible samples")
	print("AUDIO PASS: menu theme produced %d mixed frames; peak %.4f" % [frames.size(),peak])
	audio.music.stop()
	audio.flight(true)
	audio.speak("radio_briefing")
	await get_tree().create_timer(.1).timeout
	capture.clear_buffer()
	await get_tree().create_timer(1.5).timeout
	frames=capture.get_buffer(capture.get_frames_available())
	peak=0
	for frame in frames: peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	assert(peak>.001,"Radio/rotor produced no audible samples")
	print("AUDIO PASS: rotor/radio produced %d mixed frames; peak %.4f" % [frames.size(),peak])
	audio.flight(false)
	await get_tree().create_timer(.2).timeout
	capture.clear_buffer()
	audio.fire_cannon(0)
	await get_tree().create_timer(.35).timeout
	frames=capture.get_buffer(capture.get_frames_available())
	peak=0
	for frame in frames: peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	assert(peak>.01,"Cannon produced no audible mixed samples")
	print("AUDIO PASS: cannon produced %d mixed frames; peak %.4f" % [frames.size(),peak])
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	smoke_test=true
	await quit_game()

func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(path)
	get_viewport().get_texture().get_image().save_png(path + "/" + capture_kind + ".png")
	print("CAPTURE SAVED")
	await quit_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func quit_game() -> void:
	if quitting: return
	quitting = true
	active = false
	paused = false
	if not smoke_test and not capture_test: profile.save_profile()
	audio.shutdown()
	clear_combat()
	await get_tree().create_timer(.4).timeout
	get_tree().quit(0)
