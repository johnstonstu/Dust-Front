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

func simple_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .86
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
	sm.sky_top_color = [Color("2c587b"), Color("263b5e"), Color("322739"), Color("0b1224")][biome]
	sm.sky_horizon_color = [Color("c1c5bb"), Color("a9c5da"), Color("a88379"), Color("2a3d55")][biome]
	sm.ground_horizon_color = sm.sky_horizon_color
	sm.ground_bottom_color = Color("272d30") if biome != 3 else Color("0a0f16")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = [Color("b7c9d5"), Color("9bb7e0"), Color("a1a6c5"), Color("4d6288")][biome]
	env.ambient_light_energy = .32 if biome == 3 else (.5 if biome != 1 else .5)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = sm.sky_horizon_color
	env.fog_density = .00055 if biome == 3 else .00032
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = [Vector3(-43,-28,0),Vector3(-28,45,0),Vector3(-20,-65,0),Vector3(-12,110,0)][biome]
	sun.light_color = [Color("ffe3b8"),Color("d9e9ff"),Color("ffb992"),Color("7aa0d8")][biome]
	sun.light_energy = .35 if biome == 3 else (.7 if biome == 1 else 1.05)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300
	add_child(sun)
	if biome == 3:
		var moon := OmniLight3D.new()
		moon.position = Vector3(180,220,-120)
		moon.light_color = Color("9ec4ff")
		moon.light_energy = 1.4
		moon.omni_range = 900
		add_child(moon)
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
	var rock_mat := simple_mat([Color("746a55"),Color("65747d"),Color("3d3839"),Color("5a5348")][biome])
	rock_mat.albedo_texture = load("res://assets/textures/rock_color.png")
	rock_mat.uv1_triplanar = true
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
	var panel := simple_mat(Color("798071") if biome != 3 else Color("3d4a52"))
	panel.albedo_texture = load("res://assets/textures/metal_color.png")
	panel.normal_enabled = true
	panel.normal_texture = load("res://assets/textures/metal_normal.png")
	panel.uv1_triplanar = true
	for i in range(6):
		var x := -70.0 + i * 28
		var z := 65.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(17,8,24)
		add_mesh(mesh,panel,Vector3(x,height_at(x,z)+4,z))
	var pad := CylinderMesh.new()
	pad.top_radius = 22
	pad.bottom_radius = 22
	pad.height = .4
	var py := height_at(0,0)+.7
	add_mesh(pad,simple_mat(Color("424b50") if biome != 3 else Color("2a343c")),Vector3(0,py,0))
	for x in [-5.0,5.0,0.0]:
		var stripe := BoxMesh.new()
		stripe.size = Vector3(2,.05,15) if x else Vector3(10,.05,2)
		add_mesh(stripe,simple_mat(Color("e3cc81") if biome != 3 else Color("6fd0c4")),Vector3(x,py+.25,0))
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
		light.light_energy = 2 if biome != 3 else 3.2
		light.omni_range = 20
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
	mesh.surface_set_material(0,simple_mat(Color("233d35")))
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
	var lava := simple_mat(Color("ff591f"))
	lava.emission_enabled = true
	lava.emission = Color("ff4009")
	lava.emission_energy_multiplier = .7
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
	var water := simple_mat(Color("1d6a78"))
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.albedo_color = Color(.12,.42,.48,.72)
	water.emission_enabled = true
	water.emission = Color("2ec4b6")
	water.emission_energy_multiplier = .45
	water.roughness = .08
	var pool := CylinderMesh.new()
	pool.top_radius = 95
	pool.bottom_radius = 95
	pool.height = .8
	pool.radial_segments = 32
	var cy := height_at(120,-40)+.4
	add_mesh(pool,water,Vector3(120,cy,-40))
	var palm_mat := simple_mat(Color("1f3a2c"))
	for i in range(18):
		var angle := i * TAU / 18.0
		var x := 120 + cos(angle) * 110
		var z := -40 + sin(angle) * 110
		var trunk := CylinderMesh.new()
		trunk.top_radius = .35
		trunk.bottom_radius = .7
		trunk.height = 10
		add_mesh(trunk,simple_mat(Color("4a3728")),Vector3(x,height_at(x,z)+5,z))
		var crown := SphereMesh.new()
		crown.radius = 3.2
		crown.height = 4.5
		add_mesh(crown,palm_mat,Vector3(x,height_at(x,z)+11,z),Vector3(1.4,.7,1.4))
	var beacon := OmniLight3D.new()
	beacon.position = Vector3(120,cy+8,-40)
	beacon.light_color = Color("48e0c8")
	beacon.light_energy = 2.5
	beacon.omni_range = 80
	add_child(beacon)

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
