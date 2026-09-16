extends Control

var game
var panel: PanelContainer
var title: Label
var pilot: Label
var message: Label
var tabs: TabContainer
var launch: Button
var back: Button
var mode := "hangar"
var missions: Array[Button] = []
var primary: OptionButton
var secondary: OptionButton
var loadout_copy: Label
var upgrades := {}
var mission_brief: Label
var rank_progress: ProgressBar
var audio_sliders := {}

func text(parent: Node, value: String, size: int = 18) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("d4e1de"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func button(parent: Node, value: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size.y = 40
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func tab(name_text: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = name_text
	for side in ["left","top","right","bottom"]:
		margin.add_theme_constant_override("margin_"+side,18)
	tabs.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",10)
	margin.add_child(col)
	return col

func setup(g) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(.015,.025,.035,.70)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.custom_minimum_size.x = 720
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0d1b23")
	style.border_color = Color("517167")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel",style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",12)
	panel.add_child(col)
	title = text(col,"DUST FRONT / FLIGHT OPERATIONS",30)
	title.add_theme_color_override("font_color",Color("f3d38b"))
	pilot = text(col,"",16)
	rank_progress=ProgressBar.new()
	rank_progress.custom_minimum_size.y=6
	rank_progress.show_percentage=false
	col.add_child(rank_progress)
	message = text(col,"Choose your mission and loadout. Progress saves automatically.",16)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(660,340)
	col.add_child(tabs)
	var mission_col := tab("MISSIONS")
	mission_brief=text(mission_col,"",16)
	for i in range(game.Campaign.MISSIONS.size()):
		var idx := i
		var b := button(mission_col,"",func():
			game.mission_index = idx
			game.audio.cue("click")
			refresh())
		missions.append(b)
	text(mission_col,"3 sweeps per operation • Clear hardpoints and defeat the command ace to unlock the next theater.",14)
	var loadout := tab("LOADOUT")
	primary = OptionButton.new()
	primary.custom_minimum_size.y = 38
	for p in game.Campaign.PRIMARY:
		primary.add_item(p.name + "  /  RANK " + str(p.rank))
	loadout.add_child(primary)
	primary.item_selected.connect(func(index):
		if game.Campaign.PRIMARY[index].rank <= game.profile.rank():
			game.profile.primary = index
			game.profile.save_profile()
			game.audio.cue("click")
		refresh())
	secondary = OptionButton.new()
	secondary.custom_minimum_size.y = 38
	for p in game.Campaign.SECONDARY:
		secondary.add_item(p.name + "  /  RANK " + str(p.rank))
	loadout.add_child(secondary)
	secondary.item_selected.connect(func(index):
		if game.Campaign.SECONDARY[index].rank <= game.profile.rank():
			game.profile.secondary = index
			game.profile.save_profile()
			game.audio.cue("click")
		refresh())
	loadout_copy = text(loadout,"",16)
	var upgrade := tab("UPGRADES")
	for kind in ["armor","engine","cannon"]:
		var key: String = kind
		upgrades[key] = button(upgrade,"",func():
			if game.profile.buy(key):
				game.audio.cue("reward")
			refresh())
	text(upgrade,"Permanent upgrades • 3 tiers each\nArmor: +25 hull / Engine: +7 m/s / Cannon: +15% damage per tier",15)
	var sound := tab("AUDIO")
	for pair in [["master","Master volume"],["effects","Weapons & effects"],["rotor","Helicopter rotor"],["music","Theme music"]]:
		var key: String = pair[0]
		var row := HBoxContainer.new()
		sound.add_child(row)
		var caption := text(row,pair[1],16)
		caption.custom_minimum_size.x = 205
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = .01
		slider.value = game.profile.get(key)
		audio_sliders[key]=slider
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		slider.value_changed.connect(func(value):
			game.profile.set(key,value)
			game.audio.apply_levels())
		slider.drag_ended.connect(func(_changed): game.profile.save_profile())
	button(sound,"PREVIEW ROTOR + WEAPON",func():
		game.audio.cue("rotor")
		game.audio.cue("cannon"))
	button(sound,"RADIO CHECK",func(): game.audio.speak("radio_briefing"))
	button(sound,"RESTORE AUDIBLE LEVELS / UNMUTE",func():
		game.audio.restore_audible()
		refresh())
	text(sound,"CC0 helicopter: aquinn / OpenGameArt\nCombat effects: Kenney Sci-fi Sounds • Edited and mixed for Dust Front",14)
	var controls := tab("FLIGHT")
	for pair in [["sensitivity","Aim sensitivity",.3,2.0],["camera_shake","Camera shake",0.0,1.0]]:
		var key: String = pair[0]
		text(controls,pair[1],16)
		var slider := HSlider.new()
		slider.min_value=pair[2]
		slider.max_value=pair[3]
		slider.step=.05
		slider.value=game.profile.get(key)
		controls.add_child(slider)
		slider.value_changed.connect(func(value):
			game.profile.set(key,value)
			game.profile.save_profile())
	text(controls,"Shift / X: boost • Q / Y: defensive burst\nController Start pauses. Disconnecting pauses automatically.\nUse mouse or keyboard at any time to switch back.",14)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	col.add_child(actions)
	launch = button(actions,"LAUNCH SORTIE",func():
		if mode == "paused": game.set_pause(false)
		else: game.start_game())
	launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back = button(actions,"RETURN TO HANGAR",func(): game.return_to_hangar())
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(actions,"MAIN MENU",func(): game.return_to_start())
	button(actions,"QUIT",func():
		game.profile.save_profile()
		game.quit_game())
	refresh()
	launch.grab_focus()

func _input(event: InputEvent) -> void:
	if not visible or mode=="paused": return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
			var direction := -1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1
			tabs.current_tab=posmod(tabs.current_tab+direction,tabs.get_tab_count())
			get_viewport().set_input_as_handled()

func open(new_mode: String, note: String = "") -> void:
	mode = new_mode
	show()
	tabs.visible = mode != "paused"
	back.visible = mode == "paused"
	launch.text = "RESUME FLIGHT" if mode == "paused" else "LAUNCH SORTIE"
	title.text = {"paused":"SORTIE PAUSED","hangar":"DUST FRONT / HANGAR","victory":"OPERATION COMPLETE","defeat":"SORTIE ENDED"}.get(mode,"DUST FRONT")
	message.text = note if not note.is_empty() else ("Flight and combat are paused. Esc resumes. M toggles sound." if mode == "paused" else "Choose a mission, equip your aircraft, and launch. Progress saves automatically.")
	refresh()
	launch.grab_focus()

func refresh() -> void:
	var p = game.profile
	for key in audio_sliders: audio_sliders[key].set_value_no_signal(p.get(key))
	rank_progress.value=p.xp%250/2.5 if p.rank()<10 else 100
	mission_brief.text=game.Campaign.MISSIONS[game.mission_index].brief
	pilot.text = "PILOT RANK %02d  /  XP %d  /  CREDITS %d  /  NEXT RANK %d XP" % [p.rank(),p.xp,p.credits,(p.rank())*250]
	if p.rank() >= 10:
		pilot.text = "PILOT RANK 10  /  XP %d  /  CREDITS %d  /  MAX RANK" % [p.xp,p.credits]
	for i in range(missions.size()):
		var available: bool = i < p.unlocked
		missions[i].text = ("▶ " if i == game.mission_index else "   ") + game.Campaign.MISSIONS[i].name + ("  /  CLEARED" if i in p.completed else "  /  LOCKED" if not available else "  /  READY")
		missions[i].disabled = not available
	for i in range(primary.item_count):
		primary.set_item_disabled(i,game.Campaign.PRIMARY[i].rank > p.rank())
	for i in range(secondary.item_count):
		secondary.set_item_disabled(i,game.Campaign.SECONDARY[i].rank > p.rank())
	primary.select(p.primary)
	secondary.select(p.secondary)
	loadout_copy.text = game.Campaign.PRIMARY[p.primary].description + "\n\n" + game.Campaign.SECONDARY[p.secondary].description + "\n\nMissile ammunition replenishes between waves. Cannon ammo is unlimited."
	for key in upgrades:
		var tier := int(p.get(key))
		upgrades[key].text = "%s  /  TIER %d OF 3  /  %s" % [key.to_upper(),tier,"MAXED" if tier >= 3 else str(p.cost(key))+" CREDITS"]
		upgrades[key].disabled = tier >= 3 or p.credits < p.cost(key)
	if not p.last_error.is_empty():
		message.text = p.last_error
