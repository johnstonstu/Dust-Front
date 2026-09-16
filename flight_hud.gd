extends Control

var game
var font = ThemeDB.fallback_font
var mint := Color("a4f5cf")
var muted := Color("839eaa")
var amber := Color("ffd28c")

func text_at(p: Vector2, value: String, pixels: int = 16, color: Color = Color.WHITE) -> void:
	draw_string(font,p+Vector2(1,1),value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,Color(0,0,0,.8))
	draw_string(font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func card(rect: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.025,.055,.073,.9)
	style.border_color = Color(.25,.43,.47,.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	draw_style_box(style,rect)

func bar(p: Vector2, width: float, value: float, color: Color) -> void:
	draw_rect(Rect2(p,Vector2(width,6)),Color(.2,.3,.34,.6))
	draw_rect(Rect2(p,Vector2(width*clampf(value,0,1),6)),color)

func _draw() -> void:
	if game == null or not game.active or game.paused: return
	var w := size.x
	var h := size.y
	var center := size/2
	card(Rect2(24,24,260,78))
	text_at(Vector2(40,49),game.Campaign.MISSIONS[game.loaded_mission].name,17,mint)
	text_at(Vector2(40,75),("ENDLESS / WAVE %d" if game.run_mode=="endless" else "SWEEP %d / 3") % game.wave,14,muted)
	for i in range(3):
		draw_circle(Vector2(210+i*22,71),5,mint if i < game.wave else muted.darkened(.6))
	text_at(Vector2(w-170,205),"TACTICAL / 380 m",12,muted)
	# Heading tape stays above the flight path.
	var bearing := fposmod(-rad_to_deg(game.heading),360)
	card(Rect2(center.x-182,10,364,83))
	for i in range(-3,4):
		var x := center.x+i*52
		draw_line(Vector2(x,30),Vector2(x,37),muted,1)
		text_at(Vector2(x-13,55),"%03d" % int(fposmod(bearing+i*15,360)),12,muted)
	draw_colored_polygon(PackedVector2Array([Vector2(center.x-5,17),Vector2(center.x+5,17),Vector2(center.x,25)]),mint)
	# Clear, compact objective with a live remaining count.
	var objective := "%d CONTACTS REMAIN" % game.enemies.size()
	if game.enemies.is_empty(): objective = "RESUPPLY  /  %.0f s" % maxf(0,4-game.next_wave)
	text_at(Vector2(center.x-100,83),objective,16,amber)
	var alert := ""
	if game.craft.position.y-game.ground_height(game.craft.position.x,game.craft.position.z)<10: alert="TERRAIN / CLIMB"
	elif game.health<game.profile.max_health()*.25: alert="CRITICAL DAMAGE"
	elif absf(game.craft.position.x)>1120 or absf(game.craft.position.z)>1120: alert="BOUNDARY / TURN BACK"
	if not game.profile.last_error.is_empty(): alert="PROGRESS SAVE FAILED / SEE HANGAR"
	if not alert.is_empty():
		card(Rect2(center.x-160,105,320,36))
		text_at(Vector2(center.x-140,128),alert,15,Color.CORAL)
	# Aircraft condition and energy.
	card(Rect2(24,h-172,250,132))
	var hp: float = game.health/game.profile.max_health()
	text_at(Vector2(40,h-144),"AIRFRAME",13,muted)
	text_at(Vector2(174,h-144),"%03d%%" % int(hp*100),22,mint if hp>.3 else amber)
	bar(Vector2(40,h-132),218,hp,mint if hp>.3 else Color.CORAL)
	text_at(Vector2(40,h-104),"%03d" % int(game.velocity.length()*3.6),24)
	text_at(Vector2(94,h-104),"km/h",12,muted)
	text_at(Vector2(161,h-104),"%03d m" % int(game.craft.position.y-game.ground_height(game.craft.position.x,game.craft.position.z)),18)
	text_at(Vector2(40,h-76),"BOOST",12,muted)
	bar(Vector2(96,h-84),162,game.boost_energy/100,mint)
	# Weapon cards use simple cannon and missile silhouettes.
	card(Rect2(w-304,h-172,280,132))
	text_at(Vector2(w-284,h-145),game.Campaign.PRIMARY[game.primary_id].name.split(" / ")[0],18,mint)
	text_at(Vector2(w-121,h-145),"CANNON",12,muted)
	draw_rect(Rect2(w-280,h-129,25,8),mint)
	draw_line(Vector2(w-255,h-125),Vector2(w-223,h-125),mint,3)
	text_at(Vector2(w-196,h-120),"FIRING" if game.cannon_flash>0 else "UNLIMITED",12,amber if game.cannon_flash>0 else muted)
	text_at(Vector2(w-284,h-91),game.Campaign.SECONDARY[game.secondary_id].name.split(" / ")[0],17,amber)
	text_at(Vector2(w-91,h-91),"%02d" % game.missile_ammo,26,amber)
	bar(Vector2(w-284,h-73),240,1-game.rocket_timer/game.Campaign.SECONDARY[game.secondary_id].cooldown,amber)
	text_at(Vector2(w-284,h-50),"READY" if game.rocket_timer<=0 else "RELOADING",11,muted)
	# Reticle and hit confirmation.
	# Short instrument ticks give scale without covering the scene.
	for i in range(-2,3):
		var y := center.y+i*22
		draw_line(Vector2(center.x-150,y),Vector2(center.x-140,y),Color(.6,.9,.8,.45),1)
		draw_line(Vector2(center.x+140,y),Vector2(center.x+150,y),Color(.6,.9,.8,.45),1)
	for sign_x in [-1,1]:
		for sign_y in [-1,1]:
			var p := center+Vector2(sign_x*14,sign_y*14)
			draw_line(p,p+Vector2(sign_x*8,0),mint,1.5,true)
			draw_line(p,p+Vector2(0,sign_y*8),mint,1.5,true)
	draw_circle(center,2,mint)
	if game.hit_flash>0:
		text_at(center+Vector2(-12,52),"HIT",12,amber)
		for i in range(4):
			var dir := Vector2.ONE.rotated(i*PI/2).normalized()
			draw_line(center+dir*26,center+dir*34,amber,2,true)
	if game.impact_timer>0 and not game.camera.is_position_behind(game.impact_position):
		var impact: Vector2 = game.camera.unproject_position(game.impact_position)
		text_at(impact+Vector2(30,-12-(.45-game.impact_timer)*35),"−%d" % int(game.impact_damage),20,amber)
	if game.damage_flash>0:
		draw_rect(Rect2(Vector2.ZERO,size),Color(1,.12,.06,game.damage_flash*.14),false,8)
		if game.last_damage_direction.length_squared()>.1:
			var local_direction: Vector3 = game.craft.basis.inverse()*game.last_damage_direction
			var angle := Vector2(local_direction.x,local_direction.z).angle()
			draw_arc(center,76,angle-.3,angle+.3,20,Color(1,.35,.2,game.damage_flash),4,true)
	if not game.reward_text.is_empty() and game.reward_timer>0:
		var reward_width := font.get_string_size(game.reward_text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		text_at(Vector2(center.x-reward_width/2,center.y+92),game.reward_text,14,amber)
	# Bracket locked targets. An edge arrow points toward the nearest contact.
	if is_instance_valid(game.target) and not game.camera.is_position_behind(game.target.position):
		var p: Vector2 = game.camera.unproject_position(game.target.position)
		draw_rect(Rect2(p-Vector2(24,24),Vector2(48,48)),amber,false,1.5)
		for enemy in game.enemies:
			if enemy.node==game.target:
				bar(p+Vector2(-24,31),48,enemy.hp/enemy.max_hp,amber)
				text_at(p+Vector2(-35,-33),enemy.kind.to_upper(),12,amber)
		text_at(p+Vector2(-24,52),"%d m" % int(game.craft.position.distance_to(game.target.position)),12,amber)
		if not game.camera.is_position_behind(game.aim_point):
			var lead: Vector2 = game.camera.unproject_position(game.aim_point)
			draw_arc(lead,6,0,TAU,24,mint,1.5,true)
			draw_line(p,lead,Color(.6,.9,.8,.35),1,true)
	elif not game.enemies.is_empty():
		var nearest: Node3D = game.enemies[0].node
		for enemy in game.enemies:
			if enemy.node.position.distance_squared_to(game.craft.position)<nearest.position.distance_squared_to(game.craft.position): nearest=enemy.node
		var local: Vector3 = game.camera.global_basis.inverse()*(nearest.position-game.camera.position)
		var direction := Vector2(local.x,-local.y)
		if local.z>0: direction.y=absf(direction.y)+200
		if direction.length()<1: direction=Vector2.UP
		direction=direction.normalized()
		var p := center+direction*minf(w*.28,h*.29)
		draw_colored_polygon(PackedVector2Array([p+direction*10,p-direction*7+direction.orthogonal()*6,p-direction*7-direction.orthogonal()*6]),amber)
		text_at(p+Vector2(14,5),"CONTACT",11,amber)
	var hint := "LS fly  RS aim  A/B altitude  RT/RB cannon  LT/LB missile  X boost  Y countermeasures  Start pause" if game.using_pad else "WASD fly  Mouse aim  Space/C altitude  Clicks fire  Shift boost  Q countermeasures  Esc pause"
	text_at(Vector2(28,h-16),hint,12,muted)
	text_at(Vector2(center.x-92,h-58),"COUNTERMEASURES  " + ("READY" if game.flare_cooldown<=0 else "%.0f s" % game.flare_cooldown),12,mint)
	if game.radio_timer>0:
		var box_width := minf(640,w-64)
		card(Rect2(center.x-box_width/2,h-283,box_width,91))
		text_at(Vector2(center.x-box_width/2+16,h-258),"● COMMAND  /  RADIO",12,amber)
		var lines: PackedStringArray = game.radio_label.text.split("\n")
		var words := lines[lines.size()-1].replace("\"","").split(" ")
		var line := ""
		var y := h-235
		for word in words:
			if font.get_string_size(line+word,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x>box_width-36:
				text_at(Vector2(center.x-box_width/2+16,y),line,15)
				line=""
				y+=20
			line+=word+" "
		text_at(Vector2(center.x-box_width/2+16,y),line,15)
