extends Control
var game
func _draw() -> void:
	if game == null:
		return
	var center := size / 2
	draw_circle(center,76,Color(.025,.055,.065,.85))
	draw_arc(center,76,0,TAU,64,Color("648078"),1.5,true)
	draw_arc(center,38,0,TAU,48,Color(.3,.45,.43,.4),1,true)
	for i in [-2,-1,1,2]:
		var distance := float(i)*25
		var extent := sqrt(76*76-distance*distance)
		draw_line(center+Vector2(distance,-extent),center+Vector2(distance,extent),Color(.3,.5,.5,.14))
		draw_line(center+Vector2(-extent,distance),center+Vector2(extent,distance),Color(.3,.5,.5,.14))
	var sweep := Vector2.UP.rotated(game.elapsed*.8)
	draw_line(center,center+sweep*74,Color(.5,1,.8,.35),1.5,true)
	draw_line(center+Vector2(-76,0),center+Vector2(76,0),Color(.3,.45,.43,.3))
	draw_line(center+Vector2(0,-76),center+Vector2(0,76),Color(.3,.45,.43,.3))
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-7),center+Vector2(-4,5),center+Vector2(4,5)]),Color("b6fbd6"))
	for e in game.enemies:
		var offset: Vector3 = game.craft.global_basis.inverse()*(e.node.position-game.craft.position)
		var p := (Vector2(offset.x,offset.z)/5).limit_length(72)
		var tint := Color("ff9a3a") if e.kind == "sam" else Color("ff735a")
		draw_circle(center+p,4 if e.kind in ["ace","gunship","sam"] else 2.6,tint)
		if e.node==game.target: draw_arc(center+p,7,0,TAU,20,Color("ffd28c"),1,true)
	for h in game.hardpoints:
		var offset: Vector3 = game.craft.global_basis.inverse()*(h.node.position-game.craft.position)
		var p := (Vector2(offset.x,offset.z)/5).limit_length(72)
		draw_rect(Rect2(center+p-Vector2(3,3),Vector2(6,6)),Color("efbb7c"))
		if h.node==game.target: draw_arc(center+p,8,0,TAU,20,Color("ffd28c"),1,true)
