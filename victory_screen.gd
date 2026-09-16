extends Control

var game
var clock := 0.0
var sparks: Array[Dictionary] = []
var heading: Label
var report: Label
var next_button: Button
var cleared_mission := 0

func setup(g) -> void:
	game=g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x=680
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color=Color(.018,.04,.055,.94)
	style.border_color=Color("d8b679")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left=36
	style.content_margin_right=36
	style.content_margin_top=32
	style.content_margin_bottom=32
	panel.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	panel.add_child(column)
	var tag := Label.new()
	tag.text="DUST FRONT  /  AFTER-ACTION REPORT"
	tag.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_color",Color("94cbbb"))
	column.add_child(tag)
	heading=Label.new()
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",42)
	heading.add_theme_color_override("font_color",Color("ffdda0"))
	column.add_child(heading)
	report=Label.new()
	report.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	report.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	report.add_theme_font_size_override("font_size",18)
	column.add_child(report)
	next_button=button(column,"NEXT OPERATION",func():
		hide()
		game.start_game())
	button(column,"KEEP FLYING  /  ENDLESS MODE",func():
		hide()
		game.mission_index=cleared_mission
		game.start_game("endless"))
	button(column,"RETURN TO HANGAR",func():
		hide()
		game.return_to_hangar())
	var hint := Label.new()
	hint.text="Endless: escalating waves, regular resupply, XP and credits retained."
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",13)
	column.add_child(hint)
	hide()

func button(parent: Node,value: String,action: Callable) -> Button:
	var b := Button.new()
	b.text=value
	b.custom_minimum_size.y=46
	parent.add_child(b)
	b.pressed.connect(action)
	return b

func celebrate(index: int,reward: int) -> void:
	cleared_mission=index
	clock=0
	sparks.clear()
	var random := RandomNumberGenerator.new()
	random.seed=900+index
	for i in range(150):
		sparks.append({"x":random.randf(),"y":random.randf(),"speed":random.randf_range(.06,.18),"length":random.randf_range(3,13),"phase":random.randf()*TAU})
	var won_campaign: bool = game.profile.completed.size()==3
	if won_campaign: game.mission_index=index
	heading.text="CAMPAIGN COMPLETE" if won_campaign else "OPERATION COMPLETE"
	report.text="%s\n\n%d HOSTILES DOWN  •  +%d CREDITS\nPILOT RANK %d  •  %.0f SECONDS\n\nCommand: Mission complete. Return to base for resupply and upgrades." % [game.Campaign.MISSIONS[index].name,game.kills,reward,game.profile.rank(),game.elapsed]
	report.add_theme_font_size_override("font_size",16)
	next_button.text="REPLAY OPERATION" if won_campaign else "NEXT OPERATION"
	show()
	next_button.grab_focus()

func _process(delta: float) -> void:
	if not visible: return
	clock+=delta
	queue_redraw()

func _draw() -> void:
	if not visible: return
	draw_rect(Rect2(Vector2.ZERO,size),Color(.01,.025,.045,.86))
	# Slow searchlights and drifting embers avoid a strobing victory flash.
	for side in [-1,1]:
		var origin := Vector2(size.x/2+side*size.x*.42,size.y)
		var tip := Vector2(size.x/2+sin(clock*.45+side)*size.x*.35,0)
		draw_colored_polygon(PackedVector2Array([origin,tip+Vector2(-90,0),tip+Vector2(90,0)]),Color(.45,.72,.67,.07))
	for spark in sparks:
		var y := fposmod(spark.y-clock*spark.speed,1.0)*size.y
		var x: float = spark.x*size.x+sin(clock+spark.phase)*16
		draw_line(Vector2(x,y),Vector2(x-2,y+spark.length),Color(1,.72,.32,.5),2,true)
