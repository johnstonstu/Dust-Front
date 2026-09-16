extends Control

var game
var clock := 0.0
var sound_status: Label
var endless_button: Button

func setup(g) -> void:
	game=g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	column.offset_left=70
	column.offset_right=540
	column.offset_top=-270
	column.offset_bottom=270
	column.add_theme_constant_override("separation",14)
	label(column,"APACHE  /  TACTICAL AIR OPERATIONS",16,Color("91cbbf"))
	label(column,"DUST FRONT",58,Color("ffdaa0"))
	label(column,"Own the sky. Bring your crew home.",20,Color("d4e1e5"))
	var p=game.profile
	label(column,"PILOT %02d  •  %d CREDITS  •  %d / 3 OPERATIONS CLEARED" % [p.rank(),p.credits,p.completed.size()],14,Color("8ca5b0"))
	var go=button(column,"DEPLOY  →  "+game.Campaign.MISSIONS[game.mission_index].name,func(): game.start_game())
	button(column,"HANGAR  /  LOADOUT & UPGRADES",func():
		hide()
		game.hangar.open("hangar"))
	endless_button=button(column,"ENDLESS MODE",func(): game.start_game("endless"))
	endless_button.visible=not p.completed.is_empty()
	button(column,"SOUND CHECK / UNMUTE",func():
		game.audio.restore_audible()
		game.audio.speak("radio_briefing"))
	sound_status=label(column,"",14,Color("91cbbf"))
	var outputs := OptionButton.new()
	column.add_child(outputs)
	for device in AudioServer.get_output_device_list(): outputs.add_item(device)
	outputs.item_selected.connect(func(index): AudioServer.output_device=outputs.get_item_text(index))
	button(column,"QUIT",func(): game.quit_game())
	go.grab_focus()

func label(parent: Node,value: String,pixels: int,color: Color) -> Label:
	var l := Label.new()
	l.text=value
	l.add_theme_font_size_override("font_size",pixels)
	l.add_theme_color_override("font_color",color)
	parent.add_child(l)
	return l

func button(parent: Node,value: String,action: Callable) -> Button:
	var b := Button.new()
	b.text=value
	b.add_theme_font_size_override("font_size",16)
	b.custom_minimum_size.y=46
	var style := StyleBoxFlat.new()
	style.bg_color=Color("122e3a")
	style.border_color=Color("487a7c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal",style)
	parent.add_child(b)
	b.pressed.connect(action)
	return b

func _process(delta: float) -> void:
	if not visible: return
	clock+=delta
	if endless_button: endless_button.visible=not game.profile.completed.is_empty()
	if sound_status:
		sound_status.text=("SOUND MUTED  /  press M or use Sound Check" if game.profile.muted else "AUDIO ONLINE  •  THEME PLAYING  •  M TO MUTE")
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(.015,.035,.055,.88))
	var center := Vector2(size.x*.79,size.y*.5)
	var radius := minf(size.x*.18,200)
	for ring in [0.35,.68,1.0]: draw_arc(center,radius*ring,0,TAU,96,Color(.2,.55,.51,.23),1,true)
	var sweep := Vector2.UP.rotated(clock*.35)
	draw_line(center,center+sweep*radius,Color(.35,.85,.7,.38),2,true)
	for i in range(5):
		var p := center+Vector2.from_angle(i*1.37)*radius*(.3+i*.13)
		draw_circle(p,3,Color("efbb7c"))
