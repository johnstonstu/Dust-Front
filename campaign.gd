extends RefCounted

const MISSIONS = [
	{"name": "01 / DUST FRONT", "biome": "desert", "brief": "Sweep the dune corridor. Defeat three waves and the command gunship.", "reward": 350},
	{"name": "02 / WHITE RIDGE", "biome": "alpine", "brief": "Climb through frozen ridges. Interceptors patrol above the snow line.", "reward": 550},
	{"name": "03 / EMBER COAST", "biome": "volcanic", "brief": "Break the volcanic blockade. Destroy the armored ace and its escort.", "reward": 800}
]
const PRIMARY = [
	{"name": "M230 / Balanced cannon", "rank": 1, "damage": 25.0, "interval": 0.11, "description": "Reliable all-round fire. 25 damage / 9 rounds per second."},
	{"name": "VULCAN / Rapid cannon", "rank": 2, "damage": 16.0, "interval": 0.055, "description": "Fast tracer stream. 16 damage / 18 rounds per second."},
	{"name": "HAMMER / Heavy cannon", "rank": 3, "damage": 58.0, "interval": 0.23, "description": "Hard-hitting shells. 58 damage / 4 rounds per second."}
]
const SECONDARY = [
	{"name": "SEEKER / Guided missile", "rank": 1, "damage": 110.0, "cooldown": 1.4, "ammo": 20, "description": "One homing missile. Best against fast single targets."},
	{"name": "HYDRA / Rocket salvo", "rank": 2, "damage": 65.0, "cooldown": 1.8, "ammo": 30, "description": "Three unguided rockets with splash damage. Uses 3 ammo."},
	{"name": "HELLFIRE / Heavy missile", "rank": 4, "damage": 250.0, "cooldown": 2.8, "ammo": 12, "description": "Heavy homing warhead with splash damage. Ideal for gunships."}
]
var xp := 0
var credits := 0
var unlocked := 1
var completed: Array[int] = []
var primary := 0
var secondary := 0
var armor := 0
var engine := 0
var cannon := 0
var master := 0.8
var effects := 0.8
var rotor := 0.65
var music := 0.6
var muted := false
var sensitivity := 1.0
var camera_shake := 0.7
var save_path := "user://campaign.cfg"
var last_error := ""

func rank() -> int:
	return mini(10, 1 + xp / 250)

func max_health() -> float:
	return 100.0 + armor * 25

func speed() -> float:
	return 55.0 + engine * 7

func cost(kind: String) -> int:
	return 180 + int(get(kind)) * 160

func buy(kind: String) -> bool:
	if kind not in ["armor", "engine", "cannon"]:
		return false
	var tier := int(get(kind))
	if tier >= 3 or credits < cost(kind):
		return false
	credits -= cost(kind)
	set(kind, tier + 1)
	save_profile()
	return true

func earn_kill(kind: String) -> void:
	var rewards := {"scout": [35, 30], "interceptor": [55, 45], "gunship": [95, 80], "ace": [180, 150]}
	var reward: Array = rewards.get(kind, [35, 30])
	xp += reward[0]
	credits += reward[1]
	save_profile()

func complete_mission(index: int) -> int:
	var first_clear := index not in completed
	var reward := int(MISSIONS[index].reward) if first_clear else int(MISSIONS[index].reward) / 3
	credits += reward
	xp += 150 if first_clear else 50
	if first_clear:
		completed.append(index)
	unlocked = maxi(unlocked, mini(3, index + 2))
	save_profile()
	return reward

func save_profile() -> bool:
	var file := ConfigFile.new()
	for key in ["xp", "credits", "unlocked", "completed", "primary", "secondary", "armor", "engine", "cannon", "master", "effects", "rotor", "music", "muted", "sensitivity", "camera_shake"]:
		file.set_value("pilot", key, get(key))
	var error := file.save(save_path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(save_path + ".tmp", save_path)
	last_error = "" if error == OK else "Progress could not be saved (%d)." % error
	return error == OK

func load_profile() -> void:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	for key in ["xp", "credits", "unlocked", "primary", "secondary", "armor", "engine", "cannon"]:
		var value = file.get_value("pilot", key, get(key))
		if value is int or value is float:
			set(key, maxi(0, int(value)))
	xp = mini(xp, 10000000)
	credits = mini(credits, 10000000)
	unlocked = clampi(unlocked, 1, 3)
	for key in ["armor", "engine", "cannon"]:
		set(key, clampi(int(get(key)), 0, 3))
	primary = clampi(primary, 0, PRIMARY.size() - 1)
	secondary = clampi(secondary, 0, SECONDARY.size() - 1)
	if PRIMARY[primary].rank > rank():
		primary = 0
	if SECONDARY[secondary].rank > rank():
		secondary = 0
	var cleared = file.get_value("pilot", "completed", [])
	completed.clear()
	if cleared is Array:
		for index in cleared:
			if index is int and index >= 0 and index < 3 and index not in completed:
				completed.append(index)
	for key in ["master", "effects", "rotor", "music"]:
		var value = file.get_value("pilot", key, get(key))
		if (value is float or value is int) and is_finite(float(value)):
			set(key, clampf(float(value), 0, 1))
	muted = file.get_value("pilot", "muted", false) == true
	for key in ["sensitivity","camera_shake"]:
		var value = file.get_value("pilot",key,get(key))
		if (value is float or value is int) and is_finite(float(value)):
			set(key,clampf(float(value),.3 if key=="sensitivity" else 0,2 if key=="sensitivity" else 1))
