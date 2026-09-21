extends Node3D
## LIRA: angular chestnut hair, ochre field jacket, indigo trousers, red scarf.
## A hierarchical, articulated model. Animation reads state, never writes it.
const Recipe = preload("res://src/render/three/mesh_recipe.gd")
const SKIN := Color("d99b69")
const HAIR := Color("442b28")
const CLOTH := Color("e2a334")
const PANTS := Color("244766")
const BOOT := Color("382f34")
const RED := Color("c52f43")
var body: Node3D
var head: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var knees: Array[Node3D] = []
var elbows: Array[Node3D] = []
var scarf: Node3D
var phase := 0.0
var landing := 0.0
var was_grounded := true
var pose := "idle"
var last_position := Vector2.ZERO

func _init(accent: Color = CLOTH) -> void:
	body = Node3D.new()
	add_child(body)
	var m := Recipe.new()
	m.loft(Vector3(0,16,0),[Vector3(0,6,4),Vector3(3,7,4),Vector3(13,8,4.8),Vector3(16,5.5,3.5)],accent)
	m.box(Vector3(0,19,0),Vector3(13,2.5,9),BOOT)
	m.box(Vector3(0,19,5),Vector3(3,2.6,1),Color("f1d582"))
	m.prism([Vector2(-1,23),Vector2(1,23),Vector2(1,30),Vector2(-1,30)],4.5,1,PANTS)
	m.box(Vector3(-4,24,4.5),Vector3(3.5,3,1),Color("be772c"))
	m.loft(Vector3(0,31,0),[Vector3(0,6,4.8),Vector3(3,6.5,5),Vector3(4,4,3)],RED)
	m.instance(body,"JacketBeltCollar")
	head = Node3D.new()
	head.position.y = 34
	body.add_child(head)
	m = Recipe.new()
	m.loft(Vector3.ZERO,[Vector3(-1,4,3.5),Vector3(1,6.5,5),Vector3(7,7,5.5),Vector3(11,5.5,4)],SKIN,10)
	# Profile nose, ears, eyebrows, cream eyes, pupils and a short mouth.
	m.gem(Vector3(0,4.5,6),Vector3(3.2,3,3),SKIN,6)
	for side in [-1,1]:
		m.gem(Vector3(side*6.7,4,0),Vector3(3,4,3),SKIN,6)
		m.box(Vector3(side*2.8,5.9,5.25),Vector3(3.4,3.4,1),Color("fff0d3"))
		m.box(Vector3(side*2.4,5.7,5.85),Vector3(1.4,2.3,.6),Color("253444"))
		m.box(Vector3(side*2.7,8,5.6),Vector3(3.8,1.1,.8),HAIR)
	m.box(Vector3(0,1.5,4.8),Vector3(2.5,.7,.8),Color("713f39"))
	m.loft(Vector3(0,0,-.5),[Vector3(7,7.5,5.8),Vector3(11,7.8,6),Vector3(14,4.5,4),Vector3(15,0,0)],HAIR,10)
	for lock in [ [Vector2(-7,8),Vector2(-3,6),Vector2(-1,12)], [Vector2(-3,10),Vector2(2,7),Vector2(5,13)], [Vector2(3,11),Vector2(8,8),Vector2(6,14)] ]:
		m.prism(lock,5.5,2,HAIR.lightened(.06))
	m.instance(head,"SculptedHead")
	for side in [-1,1]:
		var arm := Node3D.new()
		arm.position = Vector3(side*8,29,0)
		body.add_child(arm)
		arms.append(arm)
		m = Recipe.new()
		m.loft(Vector3.ZERO,[Vector3(-7,2.1,2.3),Vector3(-3,2.8,2.8),Vector3(1,3,3)],accent,6)
		m.instance(arm,"Sleeve")
		var elbow := Node3D.new()
		elbow.position.y=-7
		arm.add_child(elbow)
		elbows.append(elbow)
		m=Recipe.new()
		m.loft(Vector3(0,-5,.5),[Vector3(0,1.8,2),Vector3(5,2.1,2.2)],SKIN,6)
		m.gem(Vector3(0,-6,1),Vector3(4.8,5,5),BOOT,6)
		m.instance(elbow,"GloveForearm")
		var leg := Node3D.new()
		leg.position = Vector3(side*3.8,17,0)
		body.add_child(leg)
		legs.append(leg)
		m = Recipe.new()
		m.loft(Vector3.ZERO,[Vector3(-8,2.4,2.7),Vector3(1,3.2,3.2)],PANTS,6)
		m.instance(leg,"Thigh")
		var knee := Node3D.new()
		knee.position.y=-8
		leg.add_child(knee)
		knees.append(knee)
		m=Recipe.new()
		m.loft(Vector3.ZERO,[Vector3(-5,2.4,2.7),Vector3(0,2.5,2.7)],PANTS,6)
		m.loft(Vector3(0,-9,1.2),[Vector3(0,3.2,4.6),Vector3(2,3.5,4.8),Vector3(5,2.7,3)],BOOT,8)
		m.box(Vector3(0,-8.7,1.2),Vector3(6,1,8),Color("b99561"))
		m.instance(knee,"ShinBoot")
	scarf = Node3D.new()
	scarf.position = Vector3(-3,32,-3)
	body.add_child(scarf)
	m = Recipe.new()
	m.prism([Vector2(-19,-3),Vector2(-14,-5),Vector2(0,-1),Vector2(0,3),Vector2(-11,1)],0,1.3,RED)
	m.instance(scarf,"ScarfTail")

func animate(delta: float, velocity: Vector2, grounded: bool, state: int, face: int,
		crouch: bool = false, pound: bool = false, wall: bool = false) -> void:
	var speed := absf(velocity.x)
	phase += delta * (2.0 + speed*.065)
	if grounded and not was_grounded: landing = 1.0
	was_grounded = grounded
	landing = maxf(0.0,landing-delta*7)
	var stride := sin(phase)*clampf(speed/190,0,1)*.65
	var a := Vector2(-stride,stride)
	var l := Vector2(stride,-stride)
	var lean := -float(face)*clampf(speed/1600,0,.23)
	var compact := 1.0-landing*.13
	pose = "run" if speed>5 else "idle"
	if speed>300: pose="sprint"
	if not grounded:
		pose = "rise" if velocity.y < -45 else ("fall" if velocity.y>45 else "apex")
		a=Vector2(-.8,.8) if velocity.y<45 else Vector2(-1.6,1.6)
		l=Vector2(.45,-.65) if velocity.y<0 else Vector2(.18,-.18)
	if crouch:
		pose="slide" if speed>80 else "crouch"
		compact=.62
		a=Vector2(-.9,.9)
		l=Vector2(-.65,.65)
	if state==Runner.State.DASH:
		pose="dash"
		lean=-face*.45
		a=Vector2(face*.9,face*.6)
		l=Vector2(.7,-.9)
	if wall or state==Runner.State.HANG:
		pose="wall"
		a=Vector2(-face*1.9,-face*1.5)
		l=Vector2(-face*.5,face*.4)
	if pound:
		pose="pound"
		compact=.7
		a=Vector2(-2.2,2.2)
		l=Vector2(-.65,.65)
	if state==Runner.State.HURT:
		pose="hurt"
		a=Vector2(-1.9,1.9)
		lean=face*.4
	if state==Runner.State.DEAD:
		pose="dead"
		lean=face*1.45
		compact=.8
		a=Vector2(-1.8,1.8)
	if landing>.2 and grounded: pose="land"
	var blend := 1.0-exp(-delta*18)
	body.rotation.z=lerp_angle(body.rotation.z,lean,blend)
	body.rotation.y=lerp_angle(body.rotation.y,face*.5,blend)
	body.scale.y=lerpf(body.scale.y,compact,blend)
	body.position.y=lerpf(body.position.y,absf(sin(phase))*1.1 if grounded and speed>5 else 0.0,blend)
	for i in 2:
		arms[i].rotation.z=lerp_angle(arms[i].rotation.z,a[i],blend)
		legs[i].rotation.z=lerp_angle(legs[i].rotation.z,l[i],blend)
		var knee_bend := maxf(0,sin(phase+float(i)*PI))*.65*clampf(speed/190,0,1) if grounded else .35
		knees[i].rotation.z=lerp_angle(knees[i].rotation.z,-face*knee_bend,blend)
		elbows[i].rotation.z=lerp_angle(elbows[i].rotation.z,face*(.5 if speed>5 else .12),blend)
	scarf.rotation.y=lerp_angle(scarf.rotation.y,0.0 if face>0 else PI,blend)
	scarf.rotation.z=sin(phase*.65)*.12+clampf(speed/1000,0,.3)
	head.rotation.z=sin(phase*.3)*.025
