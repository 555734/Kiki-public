extends Node3D
const Assets = preload("res://src/render/three/assets.gd")
const Recipe = preload("res://src/render/three/mesh_recipe.gd")
var kind: String
## A painted 1-3 enemy: one quad whose picture is swapped frame by frame.
var flat := false
var _frames: Array = []
var _frame := ""
var _base_aspect := 1.0
var body: MeshInstance3D
var limbs: Array[Node3D]=[]
var phase := 0.0

func _init(which: String = "walker", size: Vector2 = Vector2(40,40)) -> void:
	kind=which
	if Stage.is_skyward_ruins() and SkySprites.has_enemy(kind):
		flat=true
		_frames=SkySprites.ENEMY_FRAMES[kind]
		body=SkySprites.enemy_quad(kind,size)
		var first: Vector2=SkySprites.size_of(_frames[0])
		_base_aspect=first.x/maxf(1.0,first.y)
		add_child(body)
		_show(_frames[0])
		return
	body=Assets.instance(kind,size)
	add_child(body)
	if kind in ["turret","black_hole","wisp"]: return
	var flying := kind in ["flyer","pursuer","sky_predator"]
	var count := 4 if kind in ["keeper","thornmite","sky_predator"] else 2
	for i in count:
		var side := -1 if i%2==0 else 1
		var limb := Node3D.new()
		add_child(limb)
		limbs.append(limb)
		var m := Recipe.new()
		if flying:
			if kind=="sky_predator":
				var rear := i>=2
				var reach := size.x*(.62 if rear else .82)
				var rise := size.y*(.34 if rear else .50)
				limb.position=Vector3(side*size.x*.16,(-size.y*.06 if rear else 0),(-18 if rear else -7))
				m.prism([Vector2(0,0),Vector2(side*reach*.58,rise*.18),
					Vector2(side*reach,rise*.72),Vector2(side*reach*.64,rise),
					Vector2(side*reach*.26,rise*.58),Vector2(0,rise*.28)],
					0,7,Color("4a1f62") if rear else Color("80509a"))
			elif kind=="flyer" and Stage.is_skyward_ruins():
				# Thin weathered sentinel wings fit the ruin palette and keep the
				# hostile silhouette distinct from the purple pursuing monster.
				limb.position=Vector3(side*size.x*.22,0,-8)
				m.prism([Vector2(0,0),Vector2(side*size.x*.48,size.y*.10),
					Vector2(side*size.x*.43,size.y*.40),Vector2(side*size.x*.14,size.y*.28)],
					0,5,Color("91a68b"))
				m.box(Vector3(side*size.x*.23,size.y*.18,3),Vector3(size.x*.27,3,4),Color("d0b76a"))
			else:
				limb.position=Vector3(side*size.x*.25,0,-8)
				m.prism([Vector2(0,0),Vector2(side*size.x*.4,size.y*.2),Vector2(side*size.x*.3,size.y*.48),Vector2(0,size.y*.25)],0,4,Color("bac8b0") if kind=="flyer" else Color("75547f"))
		else:
			limb.position=Vector3(side*size.x*.29,-size.y*.22,-size.y*.18 if i>1 else size.y*.18)
			m.loft(Vector3.ZERO,[Vector3(-size.y*.28,size.x*.15,size.y*.19),Vector3(-size.y*.17,size.x*.12,size.y*.16),Vector3(0,size.x*.08,size.y*.09)],Color("29354a"),6)
		m.instance(limb)

func _show(frame: String) -> void:
	if frame==_frame: return
	_frame=frame
	body.material_override=SkySprites.material(frame)
	var s: Vector2=SkySprites.size_of(frame)
	body.scale.x=(s.x/maxf(1.0,s.y))/_base_aspect

func animate(delta: float, speed: float, facing: float, state: int = 0) -> void:
	phase+=delta*(3+absf(speed)*.045)
	rotation.y=0
	scale.x=absf(scale.x)*(-1 if facing<0 else 1)
	if flat:
		_animate_frames(state)
		return
	for i in limbs.size():
		if kind in ["flyer","pursuer","sky_predator"]:
			limbs[i].rotation.x=sin(phase*2)*.65
			limbs[i].rotation.z=sin(phase*2)*.18*(-1 if i%2==0 else 1)
		else:
			limbs[i].rotation.z=sin(phase+float(i%2)*PI)*.3*clampf(absf(speed)/80,0,1)
	if kind=="keeper":
		body.rotation.z=.12 if state in [Keeper.State.BRACE,Keeper.State.CHARGE] else (-.18 if state==Keeper.State.STAGGER else 0.0)
	elif kind in ["pursuer","sky_predator"]:
		body.rotation.z=sin(phase)*.07
	elif kind=="thornmite":
		body.rotation.z=-.12 if state==1 else (.08 if state==2 else 0.0)
	elif kind=="wisp":
		body.rotation.z=sin(phase)*.1

## Frame choice for painted enemies. Warnings get their own picture: the mine's
## "!" before it bristles and its glow while it does, the golem's stomp.
func _animate_frames(state: int) -> void:
	if kind=="mine":
		if state==1: _show("mine_alert"); return
		if state==2: _show("mine_glow"); return
	if kind=="golem" and state==1:
		_show("golem_stomp"); return
	var rate := 10.0 if kind in ["flyer","sky_predator"] else 5.0
	_show(_frames[int(phase*rate/3.0)%_frames.size()])
	if kind in ["seedling","mine"]:
		body.position.y=sin(phase*1.3)*4.0
