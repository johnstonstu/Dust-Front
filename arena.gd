extends Node3D

const SPAN := 2600.0
const LIMIT := 1180.0
var biome := 0
var noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()

func height_at(x: float, z: float) -> float:
	var base := sin(x * .009) * cos(z * .012)
	match biome:
		1: return -9 + base * 38 + sin(x*.025+z*.019)*15 + noise.get_noise_2d(x,z)*28
		2: return -12 + base * 23 + pow(abs(sin(x*.007+z*.004)),3)*45 + noise.get_noise_2d(x,z)*14
		3: return -6 + base * 10 + sin(x*.028+z*.017)*5 + noise.get_noise_2d(x,z)*5
	return -4 + base * 12 + sin(x*.038+z*.011)*4 + noise.get_noise_2d(x,z)*6

func simple_mat(color: Color, rough: float = .86, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

func textured_mat(color: Color, albedo: String, normal: String = "", rough: float = .78, metal: float = 0.0) -> StandardMaterial3D:
	var m := simple_mat(color, rough, metal)
	m.albedo_texture = load(albedo)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.08, 0.08, 0.08)
	if not normal.is_empty():
		m.normal_enabled = true
		m.normal_texture = load(normal)
		m.normal_scale = 0.85
	return m

func add_mesh(mesh: Mesh, material: Material, pos: Vector3, size: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	o.mesh = mesh
	o.material_override = material
	add_child(o)
	o.position = pos
	o.scale = size
	return o

func build(index: int) -> void:
	biome = index
	noise.seed = 744 + biome * 71
	noise.frequency = .008
	rng.seed = 8751 + index
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = [Color("2a5478"), Color("1f3558"), Color("2c2234"), Color("070d1a")][biome]
	sm.sky_horizon_color = [Color("d2c4a4"), Color("9ebfd8"), Color("b8876f"), Color("24364f")][biome]
	sm.ground_horizon_color = sm.sky_horizon_color
	sm.ground_bottom_color = Color("272d30") if biome != 3 else Color("060a10")
	sm.sky_curve = 0.085 if biome == 3 else 0.11
	sm.sun_angle_max = 28.0 if biome == 3 else 34.0
	sm.sun_curve = 0.12
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = [Color("c4b89a"), Color("9bb7e0"), Color("a89890"), Color("3d5274")][biome]
	env.ambient_light_energy = .28 if biome == 3 else (.48 if biome == 1 else .55)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08 if biome != 3 else 0.92
	env.fog_enabled = true
	env.fog_light_color = [Color("d8c7a2"), Color("b8d0e4"), Color("c09078"), Color("1c2a3c")][biome]
	env.fog_light_energy = 1.15 if biome == 0 else (0.85 if biome == 3 else 1.0)
	env.fog_density = .00062 if biome == 3 else (.00038 if biome == 0 else .00032)
	env.fog_aerial_perspective = 0.35 if biome != 3 else 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.35 if biome == 3 else 0.22
	env.glow_bloom = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = [Vector3(-38,-32,0),Vector3(-26,45,0),Vector3(-18,-65,0),Vector3(-10,118,0)][biome]
	sun.light_color = [Color("ffd9a0"),Color("d9e9ff"),Color("ffb48a"),Color("6e95d0")][biome]
	sun.light_energy = .42 if biome == 3 else (.75 if biome == 1 else 1.15)
	sun.light_indirect_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 340
	sun.shadow_opacity = 0.72 if biome == 3 else 0.85
	add_child(sun)
	if biome == 3:
		var moon := OmniLight3D.new()
		moon.position = Vector3(180,220,-120)
		moon.light_color = Color("9ec4ff")
		moon.light_energy = 1.7
		moon.omni_range = 980
		moon.omni_attenuation = 0.6
		add_child(moon)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-25, -40, 0)
		fill.light_color = Color("3d5a78")
		fill.light_energy = 0.22
		fill.shadow_enabled = false
		add_child(fill)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 160
	for z in range(n):
		for x in range(n):
			var a := Vector2(x*SPAN/n-SPAN/2,z*SPAN/n-SPAN/2)
			var b := a+Vector2(SPAN/n,0)
			var c := a+Vector2(0,SPAN/n)
			var d := a+Vector2(SPAN/n,SPAN/n)
			for p in [a,b,c,b,d,c]:
				st.set_uv(p / 24)
				st.add_vertex(Vector3(p.x,height_at(p.x,p.y),p.y))
	st.generate_normals()
	st.generate_tangents()
	var terrain := ShaderMaterial.new()
	terrain.shader = load("res://terrain.gdshader")
	var texture_name: String = ["sand", "snow", "ash", "sand"][biome]
	for suffix in ["color", "normal", "rough"]:
		terrain.set_shader_parameter("ground_"+suffix, load("res://assets/textures/"+texture_name+"_"+suffix+".png"))
	terrain.set_shader_parameter("rock_color", load("res://assets/textures/rock_color.png"))
	terrain.set_shader_parameter("biome", biome)
	add_mesh(st.commit(),terrain,Vector3.ZERO)
	var rocks := SphereMesh.new()
	rocks.radial_segments = 7
	rocks.rings = 3
	var rock_mat := textured_mat(
		[Color("746a55"),Color("65747d"),Color("3d3839"),Color("4a453c")][biome],
		"res://assets/textures/rock_color.png",
		"res://assets/textures/rock_normal.png",
		.9
	)
	rocks.material = rock_mat
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = rocks
	multi.instance_count = 650
	for i in range(650):
		var x := rng.randf_range(-1240,1240)
		var z := rng.randf_range(-1240,1240)
		var size := Vector3(rng.randf_range(2,18),rng.randf_range(2,13),rng.randf_range(2,16))
		multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(size),Vector3(x,height_at(x,z)-.7,z)))
	var instances := MultiMeshInstance3D.new()
	instances.multimesh = multi
	add_child(instances)
	build_outpost()
	if biome == 1:
		build_forest()
	if biome == 2:
		build_lava()
	if biome == 3:
		build_oasis()

func build_outpost() -> void:
	var panel := textured_mat(
		Color("798071") if biome != 3 else Color("3d4a52"),
		"res://assets/textures/metal_color.png",
		"res://assets/textures/metal_normal.png",
		.62,
		.35
	)
	for i in range(6):
		var x := -70.0 + i * 28
		var z := 65.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(17,8,24)
		add_mesh(mesh,panel,Vector3(x,height_at(x,z)+4,z))
		# Roof accent strip for silhouette against desert sky.
		var cap := BoxMesh.new()
		cap.size = Vector3(17.2, .35, 24.2)
		var accent := simple_mat(Color("c4a46a") if biome != 3 else Color("3ec9b4"), .45, .2)
		if biome == 3:
			accent.emission_enabled = true
			accent.emission = Color("2a8f82")
			accent.emission_energy_multiplier = .35
		add_mesh(cap, accent, Vector3(x, height_at(x, z) + 8.2, z))
	var pad := CylinderMesh.new()
	pad.top_radius = 22
	pad.bottom_radius = 22
	pad.height = .4
	var py := height_at(0,0)+.7
	var pad_mat := simple_mat(Color("424b50") if biome != 3 else Color("2a343c"), .7, .15)
	pad_mat.albedo_texture = load("res://assets/textures/metal_rough.png")
	pad_mat.uv1_triplanar = true
	add_mesh(pad,pad_mat,Vector3(0,py,0))
	for x in [-5.0,5.0,0.0]:
		var stripe := BoxMesh.new()
		stripe.size = Vector3(2,.05,15) if x else Vector3(10,.05,2)
		var stripe_mat := simple_mat(Color("e3cc81") if biome != 3 else Color("6fd0c4"), .4)
		if biome == 3:
			stripe_mat.emission_enabled = true
			stripe_mat.emission = Color("4ecfbf")
			stripe_mat.emission_energy_multiplier = .8
		add_mesh(stripe,stripe_mat,Vector3(x,py+.25,0))
	for x in [-110.0,110.0]:
		var tower := CylinderMesh.new()
		tower.top_radius = .8
		tower.bottom_radius = 2
		tower.height = 38
		var y := height_at(x,85)
		add_mesh(tower,panel,Vector3(x,y+19,85))
		var light := OmniLight3D.new()
		light.position = Vector3(x,y+39,85)
		light.light_color = Color("ffc767") if biome != 3 else Color("5de0c8")
		light.light_energy = 2.4 if biome != 3 else 3.6
		light.omni_range = 28
		add_child(light)

func build_forest() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(3):
		var cone := CylinderMesh.new()
		cone.top_radius = .08
		cone.bottom_radius = 3.5-layer*.75
		cone.height = 6
		cone.radial_segments = 9
		surface.append_from(cone,0,Transform3D(Basis.IDENTITY,Vector3(0,layer*2.8,0)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = .35
	trunk.bottom_radius = .6
	trunk.height = 5
	trunk.radial_segments = 7
	surface.append_from(trunk,0,Transform3D(Basis.IDENTITY,Vector3(0,-3,0)))
	var mesh := surface.commit()
	var canopy := simple_mat(Color("1f3a32"), .92)
	canopy.albedo_texture = load("res://assets/textures/rock_color.png")
	canopy.uv1_triplanar = true
	mesh.surface_set_material(0,canopy)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = 500
	for i in range(500):
		var x := rng.randf_range(-1000,1000)
		var z := rng.randf_range(-1000,1000)
		var scale := rng.randf_range(.7,1.6)
		var p := Vector3(x,height_at(x,z)+5.5*scale,z)
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale),p))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	add_child(node)

func build_lava() -> void:
	var lava := simple_mat(Color("ff591f"), .35)
	lava.emission_enabled = true
	lava.emission = Color("ff4009")
	lava.emission_energy_multiplier = 1.15
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(350):
		var z := -700+i*4.0
		var x := 200+sin(i*.056)*90
		var nx := 200+sin((i+1)*.056)*90
		var a := Vector3(x-8,height_at(x-8,z)+.5,z)
		var b := Vector3(x+8,height_at(x+8,z)+.5,z)
		var c := Vector3(nx-8,height_at(nx-8,z+4)+.5,z+4)
		var d := Vector3(nx+8,height_at(nx+8,z+4)+.5,z+4)
		for vertex in [a,b,c,b,d,c]: surface.add_vertex(vertex)
	surface.generate_normals()
	add_mesh(surface.commit(),lava,Vector3.ZERO)

func build_oasis() -> void:
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://water.gdshader")
	water_mat.set_shader_parameter("shallow_color", Color(0.22, 0.62, 0.64, 0.76))
	water_mat.set_shader_parameter("deep_color", Color(0.04, 0.18, 0.28, 0.9))
	water_mat.set_shader_parameter("glow_color", Color(0.22, 0.85, 0.78))
	water_mat.set_shader_parameter("glow_energy", 0.7)
	var pool := CylinderMesh.new()
	pool.top_radius = 95
	pool.bottom_radius = 95
	pool.height = .8
	pool.radial_segments = 48
	var cy := height_at(120,-40)+.4
	add_mesh(pool,water_mat,Vector3(120,cy,-40))
	# Shore foam ring — bright read against dark night sand.
	var foam := TorusMesh.new()
	foam.inner_radius = 92.0
	foam.outer_radius = 96.5
	foam.rings = 24
	foam.ring_segments = 12
	var foam_mat := simple_mat(Color(0.75, 0.95, 0.92, 0.55), .2)
	foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_mat.emission_enabled = true
	foam_mat.emission = Color("9affef")
	foam_mat.emission_energy_multiplier = 0.55
	foam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	add_mesh(foam, foam_mat, Vector3(120, cy + 0.55, -40), Vector3(1, 0.08, 1))
	var palm_mat := simple_mat(Color("1f3a2c"), .9)
	for i in range(18):
		var angle := i * TAU / 18.0
		var x := 120 + cos(angle) * 110
		var z := -40 + sin(angle) * 110
		var trunk := CylinderMesh.new()
		trunk.top_radius = .35
		trunk.bottom_radius = .7
		trunk.height = 10
		add_mesh(trunk,simple_mat(Color("4a3728"), .95),Vector3(x,height_at(x,z)+5,z))
		var crown := SphereMesh.new()
		crown.radius = 3.2
		crown.height = 4.5
		add_mesh(crown,palm_mat,Vector3(x,height_at(x,z)+11,z),Vector3(1.4,.7,1.4))
	var beacon := OmniLight3D.new()
	beacon.position = Vector3(120,cy+8,-40)
	beacon.light_color = Color("48e0c8")
	beacon.light_energy = 3.2
	beacon.omni_range = 110
	add_child(beacon)
	var rim := OmniLight3D.new()
	rim.position = Vector3(120, cy + 2, -40)
	rim.light_color = Color("2a8f9a")
	rim.light_energy = 1.4
	rim.omni_range = 70
	add_child(rim)

func hardpoint_sites(wave: int) -> Array[Vector3]:
	var count := mini(3, 1 + int(wave / 2) + (1 if biome >= 2 else 0))
	var sites: Array[Vector3] = []
	for i in range(count):
		var angle := -PI * .35 + i * .55 + biome * .2
		var radius := 95.0 + i * 35.0
		var x := cos(angle) * radius
		var z := 40.0 + sin(angle) * radius
		sites.append(Vector3(x, height_at(x, z), z))
	return sites
