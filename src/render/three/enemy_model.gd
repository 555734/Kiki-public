extends Node3D
const Assets = preload("res://src/render/three/assets.gd")
const Recipe = preload("res://src/render/three/mesh_recipe.gd")
var kind: String
var body: MeshInstance3D
var limbs: Array[Node3D]=[]
var phase := 0.0

func _init(which: String = "walker", size: Vector2 = Vector2(40,40)) -> void:
	kind=which
	body=Assets.instance(kind,size)
	add_child(body)
	if kind in ["turret","black_hole","wisp"]: return
	var flying := kind in ["flyer","pursuer"]
	var count := 4 if kind in ["keeper","thornmite"] else 2
	for i in count:
		var side := -1 if i%2==0 else 1
		var limb := Node3D.new()
		add_child(limb)
		limbs.append(limb)
		var m := Recipe.new()
		if flying:
			limb.position=Vector3(side*size.x*.25,0,-8)
			m.prism([Vector2(0,0),Vector2(side*size.x*.4,size.y*.2),Vector2(side*size.x*.3,size.y*.48),Vector2(0,size.y*.25)],0,4,Color("bac8b0") if kind=="flyer" else Color("75547f"))
		else:
			limb.position=Vector3(side*size.x*.29,-size.y*.22,-size.y*.18 if i>1 else size.y*.18)
			m.loft(Vector3.ZERO,[Vector3(-size.y*.28,size.x*.15,size.y*.19),Vector3(-size.y*.17,size.x*.12,size.y*.16),Vector3(0,size.x*.08,size.y*.09)],Color("29354a"),6)
		m.instance(limb)

func animate(delta: float, speed: float, facing: float, state: int = 0) -> void:
	phase+=delta*(3+absf(speed)*.045)
	rotation.y=0
	scale.x=absf(scale.x)*(-1 if facing<0 else 1)
	for i in limbs.size():
		if kind in ["flyer","pursuer"]:
			limbs[i].rotation.x=sin(phase*2)*.65
			limbs[i].rotation.z=sin(phase*2)*.18*(-1 if i%2==0 else 1)
		else:
			limbs[i].rotation.z=sin(phase+float(i%2)*PI)*.3*clampf(absf(speed)/80,0,1)
	if kind=="keeper":
		body.rotation.z=.12 if state in [Keeper.State.BRACE,Keeper.State.CHARGE] else (-.18 if state==Keeper.State.STAGGER else 0.0)
	elif kind=="pursuer":
		body.rotation.z=sin(phase)*.07
	elif kind=="thornmite":
		body.rotation.z=-.12 if state==1 else (.08 if state==2 else 0.0)
	elif kind=="wisp":
		body.rotation.z=sin(phase)*.1
