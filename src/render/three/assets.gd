extends RefCounted
## Original Kiki meshes, authored as deterministic recipes. Each rigid object
## is one vertex-coloured draw surface. Models share resources across instances.
const Recipe = preload("res://src/render/three/mesh_recipe.gd")
static var cache: Dictionary = {}

static func palette() -> Array[Color]:
	if Stage.is_horror(): return [Color("353044"),Color("756079"),Color("76584a")]
	if Stage.is_skyward_ruins():
		# Sun-bleached limestone, restrained moss and warm cut stone.  The stage
		# needs to read as an ancient ruin in open air, not green dirt boxes.
		return [Color("b7aa82"),Color("4d8255"),Color("e7ddbd")]
	if Stage.is_sky(): return [Color("63688d"),Color("87b8ac"),Color("b0a1ac")]
	if Stage.is_keeper(): return [Color("514d60"),Color("8d8280"),Color("746776")]
	if Stage.is_quiet(): return [Color("666b75"),Color("8dabaa"),Color("8c8393")]
	return [Color("91532d"),Color("57ad3a"),Color("bb7c43")]

static func terrain(size: Vector2) -> ArrayMesh:
	var m := Recipe.new()
	var p := palette()
	var w := size.x
	var h := size.y
	if Stage.is_skyward_ruins():
		var face := p[0]
		var moss := p[1]
		var cut := p[2]
		var shade := Color("6f6b5c")
		var crack := Color("56584f")
		# Exact collision top stays at y=0. Everything below it is presentation.
		m.box(Vector3(w/2,-h/2,-42),Vector3(w,h,76),face)
		m.box(Vector3(w/2,-8,-1),Vector3(w,16,82),cut)
		m.quad(Vector3(0,0,-80),Vector3(0,0,2),Vector3(w,0,2),Vector3(w,0,-80),moss)
		m.quad(Vector3(0,-5,3),Vector3(w,-5,3),Vector3(w,-16,4),Vector3(0,-16,4),moss.darkened(.08))
		# Large masonry courses break the collider-sized rectangle into believable
		# ancient construction instead of a single plastic slab.
		for row in range(2):
			var y := -minf(h-16.0,46.0+float(row)*54.0)
			if y < -18.0:
				m.box(Vector3(w/2,y,1),Vector3(w,3,4),shade)
		for i in maxi(1,int(w/92.0)):
			var x := minf(w-18.0,28.0+float(i)*92.0)
			m.box(Vector3(x,-minf(h*.55,64.0+float(i%3)*13.0),2),Vector3(3,minf(54.0,h*.42),4),shade.darkened(.08))
		# Broken under-side: several independent hanging rock/ruin wedges. Their
		# unequal lengths make the stage silhouette readable while moving upward.
		var teeth := maxi(2,int(ceil(w/105.0)))
		for i in teeth:
			var x0 := w*(float(i)+.08)/float(teeth)
			var x1 := w*(float(i)+.92)/float(teeth)
			var cx := (x0+x1)*.5
			var drop := minf(105.0,h*.62)*(0.62+0.10*float((i*7)%4))
			m.prism([Vector2(x0,-h+8),Vector2(x1,-h+8),Vector2(cx,-h-drop)],-17,34,
				face.darkened(.08+float(i%2)*.04))
		# Sparse moss shelves and chipped highlights; deliberately irregular.
		for i in maxi(1,int(w/120.0)):
			var x := 22.0+float(i)*117.0
			if x < w-16.0:
				m.prism([Vector2(x,-2),Vector2(minf(w,x+54),-2),Vector2(minf(w,x+46),-12),Vector2(x+7,-10)],3,5,
					moss.lightened(.04))
		for i in maxi(1,int(w/150.0)):
			var x := 45.0+float(i)*143.0
			if x < w-18.0:
				m.prism([Vector2(x,-h*.30),Vector2(x+16,-h*.43),Vector2(x+29,-h*.27),Vector2(x+19,-h*.23)],3,3,crack)
		return m.mesh()
	m.box(Vector3(w/2,-h/2,-42),Vector3(w,h,76),p[0])
	m.quad(Vector3(0,0,-80),Vector3(0,0,0),Vector3(w,0,0),Vector3(w,0,-80),p[1])
	# Grass bevel stays entirely inside the collision rectangle. The bright
	# top edge is exactly y=0; no perspective/pitch moves the walkable surface.
	m.quad(Vector3(0,0,0),Vector3(w,0,0),Vector3(w,-7,1),Vector3(0,-7,1),p[1].lightened(.15))
	m.quad(Vector3(0,-7,1),Vector3(w,-7,1),Vector3(w,-16,1),Vector3(0,-16,1),p[1])
	for i in range(int(w/32)):
		var x := 10.0+i*32
		m.prism([Vector2(x,-14),Vector2(x+6,-22-(i%3)*2),Vector2(x+16,-14)],0,2,p[1].darkened(.12))
	for i in range(int(w/57)):
		var x := 23.0+i*57
		var y := -minf(h-10,38.0+float(i%3)*24)
		m.gem(Vector3(x,y,-2),Vector3(12+i%3*4,7,3),p[2],5)
	if h>90:
		m.box(Vector3(w/2,-h*.65,-2),Vector3(w,3,2),p[0].darkened(.12))
	return m.mesh()

static func mesh(kind: String, size: Vector2 = Vector2(40,40)) -> ArrayMesh:
	var key := "%s:%s:%d" % [kind,size,Stage.current()]
	if cache.has(key): return cache[key]
	var m := Recipe.new()
	var stone := palette()[2]
	var dark := Color("273447")
	var gold := Color("edb93f")
	var cyan := Color("5ed9db")
	match kind:
		"coin":
			# Twelve-sided stamped sun token with thickness and a raised diamond.
			var pts: Array = []
			for i in 12: pts.append(Vector2(cos(i*TAU/12),sin(i*TAU/12))*size.x*.5)
			m.prism(pts,0,3,gold)
			m.gem(Vector3(0,0,2.5),Vector3(size.x*.65,size.x*.65,2),Color("ffe28c"),4)
		"crystal", "sigil":
			m.gem(Vector3.ZERO,Vector3(20,32,16),cyan,5)
			m.gem(Vector3(0,0,9),Vector3(8,16,3),Color("dafbf1"),4)
		"thornmite":
			# Low stone quadruped: long back, forward horn and layered plates.
			m.prism([Vector2(-size.x*.46,-size.y*.22),Vector2(-size.x*.4,size.y*.20),Vector2(-size.x*.18,size.y*.43),Vector2(size.x*.25,size.y*.35),Vector2(size.x*.48,0),Vector2(size.x*.38,-size.y*.25)],0,size.y*.65,Color("7a5146"))
			for i in 3:
				m.gem(Vector3(-size.x*.27+i*size.x*.22,size.y*.25,0),Vector3(size.x*.29,size.y*.4,size.y*.6),Color("a47b60"),5)
			m.prism([Vector2(size.x*.24,size.y*.23),Vector2(size.x*.46,size.y*.49),Vector2(size.x*.42,size.y*.06)],4,10,Color("d3b38a"))
			m.gem(Vector3(size.x*.28,size.y*.04,size.y*.35),Vector3(12,10,4),Color("ede5cb"),5)
			m.gem(Vector3(size.x*.31,size.y*.04,size.y*.4),Vector3(5,6,2),dark,4)
		"wisp":
			m.loft(Vector3(0,-size.y*.5,0),[Vector3(0,1,1),Vector3(size.y*.3,size.x*.34,size.x*.2),Vector3(size.y*.6,size.x*.5,size.x*.27),Vector3(size.y*.87,size.x*.29,size.x*.19),Vector3(size.y,1,1)],Color("b7c5cb"),7)
			for side in [-1,1]: m.gem(Vector3(side*size.x*.16,size.y*.12,size.x*.25),Vector3(7,10,4),Color("5266a4"),4)
		"walker", "walker_spiky", "flyer", "shieldbearer", "keeper", "pursuer", "sky_predator", "turret", "black_hole":
			_enemy(m,kind,size)
		"goal":
			for side in [-1,1]:
				m.loft(Vector3(side*43,-95,-12),[Vector3(0,14,18),Vector3(12,11,14),Vector3(140,10,12),Vector3(160,13,15)],stone)
			for i in 7:
				var a := PI*float(i)/6
				m.gem(Vector3(cos(a)*43,65+sin(a)*35,-12),Vector3(27,25,29),stone,6)
			m.gem(Vector3(0,72,7),Vector3(23,34,12),cyan,4)
		"checkpoint":
			m.loft(Vector3(0,-74,-7),[Vector3(0,18,12),Vector3(8,13,9),Vector3(17,7,6),Vector3(117,5,5)],stone)
			m.gem(Vector3(0,55,-7),Vector3(26,34,20),cyan,6)
			m.box(Vector3(0,-64,-7),Vector3(35,4,22),gold)
		"hazard":
			for i in maxi(1,int(size.x/20)):
				m.loft(Vector3(-size.x/2+10+i*20,-size.y/2,0),[Vector3(0,10,10),Vector3(size.y,0,0)],Color("d6d7cc"),5)
		"spring":
			m.box(Vector3(0,size.y-3,-8),Vector3(size.x,6,28),gold)
			m.box(Vector3(0,3,-8),Vector3(size.x,6,28),dark)
			for i in 4: m.box(Vector3(0,6+i*(size.y-12)/4,-8),Vector3(size.x*.65,3,20),Color("aaa99b"))
		"switch":
			m.gem(Vector3.ZERO,Vector3(34,34,20),dark,8)
			m.gem(Vector3(0,0,10),Vector3(22,22,12),gold,4)
		"projectile", "shockwave":
			m.gem(Vector3.ZERO,Vector3(size.x,size.y,12),Color("f46d38"),6)
		"platform", "wall", "gate", "crumbling", "barricade":
			var colour := Color("597789") if kind=="platform" else stone
			m.box(Vector3(0,0,-13),Vector3(size.x,size.y,26),colour)
			m.box(Vector3(0,size.y/2-3,1),Vector3(size.x,6,3),colour.lightened(.3))
			m.box(Vector3(0,-size.y/2+3,1),Vector3(size.x,5,3),dark)
			for i in maxi(1,int(size.x/36)):
				m.gem(Vector3(-size.x/2+12+i*36,0,3),Vector3(4,4,3),gold,4)
			if kind in ["gate","wall","barricade"]:
				for side in [-1,1]: m.box(Vector3(side*size.x*.35,0,2),Vector3(4,size.y-10,3),colour.darkened(.25))
				m.gem(Vector3(0,size.y*.18,3),Vector3(size.x*.4,24,5),colour.lightened(.35),4)
		_:
			_prop(m,kind,size)
	var result: ArrayMesh = m.mesh()
	cache[key]=result
	return result

static func _enemy(m: RefCounted, kind: String, size: Vector2) -> void:
	var w := size.x
	var h := size.y
	var dark := Color("233246")
	if kind=="sky_predator":
		# Stage 1-3's pursuing enemy gets its own silhouette: a compact black-violet
		# core, hooked crown and layered vapour plates. It must remain identifiable
		# even when it is far below the runner in a vertical camera.
		var core := Color("351743")
		var violet := Color("6b2f83")
		var rim := Color("9f5ab4")
		m.gem(Vector3(0,0,-2),Vector3(w*.70,h*.76,30),core,10)
		m.gem(Vector3(-w*.18,-h*.05,2),Vector3(w*.56,h*.56,24),violet,8)
		m.gem(Vector3(w*.19,h*.04,0),Vector3(w*.50,h*.48,22),violet.lightened(.05),8)
		for side in [-1,1]:
			m.prism([Vector2(side*w*.18,-h*.22),Vector2(side*w*.50,-h*.48),
				Vector2(side*w*.35,-h*.05),Vector2(side*w*.50,h*.20),
				Vector2(side*w*.13,h*.10)],-8,16,core.darkened(.08))
			m.gem(Vector3(side*w*.17,h*.12,18),Vector3(w*.16,h*.11,5),Color("f0a0ff"),5)
		m.prism([Vector2(-w*.28,h*.24),Vector2(0,h*.52),Vector2(w*.28,h*.24),Vector2(0,h*.35)],3,8,rim)
		for i in 4:
			var x := -w*.25+float(i)*w*.17
			m.prism([Vector2(x,h*.26),Vector2(x+w*.10,h*.48+float(i%2)*h*.10),
				Vector2(x+w*.16,h*.25)],-4,7,Color("d9c8dc"))
		return
	var shell := Color("ad6239")
	if kind=="flyer": shell=Color("50758b")
	if kind in ["pursuer","black_hole"]: shell=Color("49374f")
	if kind=="keeper": shell=Color("557777")
	if kind=="shieldbearer": shell=Color("647158")
	if kind=="walker_spiky": shell=Color("9c4938")
	if Stage.is_skyward_ruins() and kind=="flyer":
		shell=Color("6b786f")
		dark=Color("343b3d")
	# Rock-beetle family: angular carapace, segmented plates, forward visor.
	m.loft(Vector3(0,-h*.35,0),[Vector3(0,w*.32,h*.22),Vector3(h*.24,w*.48,h*.3),
		Vector3(h*.66,w*.38,h*.25),Vector3(h*.82,w*.14,h*.1)],shell,8)
	m.box(Vector3(0,h*.10,h*.26),Vector3(w*.65,h*.22,4),dark)
	for side in [-1,1]:
		m.gem(Vector3(side*w*.17,h*.13,h*.31),Vector3(w*.15,h*.11,5),
			Color("f2c765") if Stage.is_skyward_ruins() and kind=="flyer" else Color("f5b541"),4)
		if kind in ["turret","black_hole"]:
			m.loft(Vector3(side*w*.29,-h*.5,2),[Vector3(0,w*.18,h*.23),Vector3(6,w*.15,h*.20),Vector3(h*.24,w*.09,h*.1)],dark,6)
		m.prism([Vector2(side*w*.25,h*.28),Vector2(side*w*.48,h*.5),Vector2(side*w*.1,h*.36)],0,8,shell.lightened(.2))
	if kind in ["pursuer","keeper","black_hole"]:
		for i in 5:
			m.prism([Vector2(-w*.28+i*w*.12,h*.02),Vector2(-w*.22+i*w*.12,-h*.16),Vector2(-w*.16+i*w*.12,h*.02)],h*.3,4,Color("e1d6bc"))
	if kind=="shieldbearer":
		m.loft(Vector3(w*.42,-h*.5,4),[Vector3(0,6,10),Vector3(h*.7,8,13),Vector3(h,3,8)],Color("cbb57e"),6)
	if kind=="walker_spiky":
		for i in 3:
			m.loft(Vector3(-w*.25+i*w*.25,h*.32,0),[Vector3(0,5,5),Vector3(h*.23,0,0)],Color("e4c295"),5)
	if kind=="turret":
		m.box(Vector3(w*.25,0,0),Vector3(w*.7,h*.22,h*.3),dark)
		m.box(Vector3(w*.6,0,0),Vector3(4,h*.3,h*.4),Color("cf9957"))
	if kind=="black_hole":
		m.gem(Vector3(0,0,h*.35),Vector3(w*.7,h*.7,20),Color("100e24"),10)

static func _prop(m: RefCounted, kind: String, size: Vector2) -> void:
	var wood := Color("775039")
	var leaf := Color("479346") if not Stage.is_horror() else Color("3e4052")
	var stone := palette()[2]
	match kind:
		"tree":
			if Stage.is_skyward_ruins():
				# Windswept summit tree: exposed roots, twisted trunk and a canopy
				# pushed sideways by the same wind that drives the vertical climb.
				var trunk_h := maxf(90.0,size.y*.56)
				m.loft(Vector3(-size.x*.12,0,-15),[Vector3(0,15,13),Vector3(trunk_h*.34,12,11),
					Vector3(trunk_h*.68,9,8),Vector3(trunk_h,5,5)],Color("6f563b"),7)
				for i in 3:
					m.prism([Vector2(-size.x*.28+i*9,3),Vector2(-size.x*.05+i*7,18),
						Vector2(size.x*.18+i*12,5)],-17,10,Color("5c4734"))
				var crown_y := trunk_h*.76
				for i in 5:
					m.gem(Vector3(-size.x*.30+float(i)*size.x*.16,crown_y+float(i%2)*18,-22),
						Vector3(size.x*.38,size.y*.24,42),Color("487553").lightened(float(i)*.025),7)
			else:
				m.loft(Vector3.ZERO,[Vector3(0,13,12),Vector3(30,10,9),Vector3(110,6,6)],wood,7)
				for i in 3: m.gem(Vector3(-35+i*33,114+float(i%2)*27,-20),Vector3(84,82,62),leaf.lightened(i*.04),7)
		"fence":
			for i in range(int(size.x/36)+1):
				m.loft(Vector3(i*36,0,-18),[Vector3(0,4,4),Vector3(42,4,4),Vector3(49,0,0)],wood,4)
			m.box(Vector3(size.x/2,20,-18),Vector3(size.x,6,6),wood.lightened(.18))
			m.box(Vector3(size.x/2,35,-18),Vector3(size.x,6,6),wood.lightened(.18))
		"pipe":
			var radius := size.x*.5/cos(PI/10)
			m.loft(Vector3.ZERO,[Vector3(0,radius*.85,26),Vector3(size.y-14,radius*.85,26),Vector3(size.y-14,radius,30),Vector3(size.y,radius,30)],Color("418879"),10)
			m.loft(Vector3(0,size.y-.2,0),[Vector3(0,size.x*.42,23),Vector3(.1,size.x*.42,23)],Color("254e4c"),10)
		"ruin_blocks":
			m.box(Vector3(0,size.y*.5,-16),Vector3(size.x,size.y,32),Color("303a47"))
			m.box(Vector3(0,size.y-3,1),Vector3(size.x,6,4),Color("526171"))
			m.box(Vector3(0,size.y*.75,2),Vector3(size.x*.65,4,3),Color("577a61"))
			m.prism([Vector2(-size.x*.3,size.y*.1),Vector2(-size.x*.1,size.y*.4),Vector2(-size.x*.12,size.y*.12)],2,2,Color("17202b"))
		"blocks":
			m.loft(Vector3(0,0,-16),[Vector3(0,size.x*.707107,28),Vector3(size.y-5,size.x*.707107,28),Vector3(size.y,size.x*.707107,24)],stone,4)
			m.gem(Vector3(0,size.y*.55,5),Vector3(size.x*.35,size.y*.35,4),stone.lightened(.25),4)
		"crate":
			m.box(Vector3(0,22,-12),Vector3(44,44,36),wood)
			for y in [4,21,39]: m.box(Vector3(0,y,7),Vector3(46,4,3),wood.lightened(.2))
			m.prism([Vector2(-22,4),Vector2(-17,1),Vector2(22,39),Vector2(17,43)],10,3,wood.lightened(.3))
		"rubble":
			for i in 4: m.gem(Vector3(-25+i*15,8+float(i%2)*4,-10),Vector3(28,22,25),stone.darkened(i*.04),6)
		"grave":
			m.loft(Vector3.ZERO,[Vector3(0,19,8),Vector3(42,17,8),Vector3(53,11,7),Vector3(55,0,0)],Color("67777d"),8)
			m.box(Vector3(0,32,8),Vector3(3,20,2),Color("344650"))
			m.box(Vector3(0,37,8),Vector3(16,3,2),Color("344650"))
		"arch":
			if Stage.is_skyward_ruins():
				var half := maxf(42.0,size.x*.32)
				var leg_h := maxf(90.0,size.y*.46)
				var block := maxf(18.0,size.x*.12)
				for side in [-1,1]:
					m.box(Vector3(side*half,leg_h*.5,-20),Vector3(block,leg_h,34),stone.darkened(.03))
					m.box(Vector3(side*half,8,-20),Vector3(block*1.55,16,40),stone.lightened(.06))
				for i in 9:
					var a := PI*float(i)/8
					var jitter := -4.0 if i in [2,7] else 0.0
					m.gem(Vector3(cos(a)*half,leg_h+sin(a)*half*.72+jitter,-20),
						Vector3(block*1.45,block*1.25,34),stone.lightened(.02*float(i%3)),6)
				m.prism([Vector2(-half-block*.2,leg_h*.15),Vector2(-half+block*.5,leg_h*.28),
					Vector2(-half+block*.25,leg_h*.10)],2,3,Color("6b7464"))
			else:
				for side in [-1,1]: m.box(Vector3(side*45,50,-20),Vector3(16,100,25),stone)
				for i in 7:
					var a := PI*float(i)/6
					m.gem(Vector3(cos(a)*45,100+sin(a)*28,-20),Vector3(24,24,28),stone,6)
		"keel":
			if Stage.is_skyward_ruins():
				# Stone underside, not the wooden hull used by 1-S.
				m.prism([Vector2(-size.x*.50,0),Vector2(size.x*.50,0),
					Vector2(size.x*.31,size.y*.38),Vector2(size.x*.08,size.y*.82),
					Vector2(-size.x*.12,size.y*.70),Vector2(-size.x*.34,size.y*.34)],-18,36,stone.darkened(.08))
				for i in 4:
					m.gem(Vector3(-size.x*.28+float(i)*size.x*.19,size.y*.22+float(i%2)*18,-2),
						Vector3(size.x*.18,size.y*.26,26),stone.darkened(.03*float(i)),6)
			else:
				m.prism([Vector2(-size.x/2,40),Vector2(-size.x*.3,4),Vector2(size.x*.3,4),Vector2(size.x/2,40)],-16,35,wood)
				for i in 6: m.box(Vector3(-size.x*.35+i*size.x*.14,29,4),Vector3(5,32,4),wood.lightened(.2))
		"cart":
			m.box(Vector3(0,35,-15),Vector3(90,30,42),wood)
			m.box(Vector3(0,51,-15),Vector3(100,6,46),wood.lightened(.15))
			for side in [-1,1]:
				var wheel: Array=[]
				for i in 10: wheel.append(Vector2(side*30+cos(i*TAU/10)*15,15+sin(i*TAU/10)*15))
				m.prism(wheel,12,6,Color("343d46"))
				m.gem(Vector3(side*30,15,17),Vector3(9,9,3),Color("b9a579"),6)
		"puddle":
			m.loft(Vector3.ZERO,[Vector3(0,size.x/2,24),Vector3(1,size.x/2,24)],Color("436574"),12)
		"roots":
			for i in 3: m.prism([Vector2(-55+i*15,1),Vector2(-30+i*13,20+i*8),Vector2(10+i*15,8),Vector2(45+i*8,0)],-15+i*3,8,wood.darkened(.15))
		"banner", "streamer":
			m.box(Vector3(0,48,-20),Vector3(4,96,4),wood)
			m.prism([Vector2(3,92),Vector2(40,88),Vector2(34,44),Vector2(17,53),Vector2(3,46)],-18,1.5,Color("993e52") if kind=="banner" else Color("468da3"))
		"crow":
			m.gem(Vector3(0,8,-15),Vector3(28,18,16),Color("283449"),6)
			m.gem(Vector3(11,16,-13),Vector3(14,14,12),Color("283449"),6)
			m.prism([Vector2(16,17),Vector2(29,14),Vector2(17,12)],-13,5,Color("b49a66"))
		"brazier":
			m.loft(Vector3.ZERO,[Vector3(0,17,17),Vector3(8,11,11),Vector3(45,8,8),Vector3(53,23,23)],Color("4b535f"),8)
			for i in 3: m.gem(Vector3(-10+i*10,64+float(i%2)*12,0),Vector3(15,34,13),Color("ed9f32"),5)
		"lantern":
			m.loft(Vector3.ZERO,[Vector3(0,11,9),Vector3(4,11,9),Vector3(7,7,6),Vector3(29,7,6),Vector3(34,12,10),Vector3(39,2,2)],Color("48515c"),6)
			m.gem(Vector3(0,17,0),Vector3(14,21,12),Color("ebb449"),6)
			for side in [-1,1]: m.box(Vector3(side*7,17,6),Vector3(2,24,2),Color("48515c"))
		"signpost":
			m.box(Vector3(0,27,-20),Vector3(6,54,6),wood)
			m.prism([Vector2(-21,35),Vector2(15,35),Vector2(28,46),Vector2(15,57),Vector2(-21,57)],-16,5,wood.lightened(.22))
		"flowers":
			for i in 3:
				m.box(Vector3(i*10,7,-15),Vector3(2,14,2),leaf)
				m.gem(Vector3(i*10,14,-15),Vector3(10,8,8),Color("f0c658"),5)
		"waterfall":
			# Several separated ribbons and foam clusters read as moving water;
			# the old single cyan rectangle looked like a luminous wall.
			var water := Color("79cce5")
			for i in 7:
				var lane_w := size.x*(.08+.018*float(i%3))
				var x := -size.x*.40+float(i)*size.x*.13
				var top := 8.0+float((i*11)%4)*7.0
				m.prism([Vector2(x-lane_w*.5,top),Vector2(x+lane_w*.5,top+3),
					Vector2(x+lane_w*.34,size.y),Vector2(x-lane_w*.42,size.y-8)],-22+float(i%2)*5,5,
					water.lightened(float(i%3)*.07))
			for i in 5:
				m.gem(Vector3(-size.x*.42+float(i)*size.x*.21,8+float(i%2)*5,-15),
					Vector3(size.x*.24,24,18),Color("e8f8fb"),7)
			for i in 4:
				m.gem(Vector3(-size.x*.34+float(i)*size.x*.22,size.y-5,-18),
					Vector3(size.x*.28,30,20),Color("c9eef5"),7)
		"ruin_column":
			var shaft := size.x*.34
			m.loft(Vector3(0,0,-18),[Vector3(0,shaft*.88,22),Vector3(14,shaft,24),
				Vector3(size.y*.78,shaft*.78,22),Vector3(size.y-20,shaft*.72,20)],stone,10)
			m.box(Vector3(0,9,-18),Vector3(size.x*.92,18,46),stone.lightened(.10))
			m.box(Vector3(0,23,-18),Vector3(size.x*.72,9,41),stone.darkened(.02))
			# Broken asymmetric capital; avoids the prefab-pillar look.
			m.prism([Vector2(-size.x*.46,size.y-24),Vector2(size.x*.34,size.y-24),
				Vector2(size.x*.45,size.y-8),Vector2(size.x*.08,size.y-1),
				Vector2(-size.x*.40,size.y-10)],-18,42,stone.darkened(.05))
			for i in 4:
				var x := -shaft*.58+float(i)*shaft*.39
				m.box(Vector3(x,size.y*.47,-.5),Vector3(3,size.y*.48,3),stone.darkened(.14))
			m.prism([Vector2(-size.x*.28,size.y*.24),Vector2(-size.x*.04,size.y*.42),
				Vector2(size.x*.08,size.y*.22)],3,3,Color("596b59"))
		"cloud_bank":
			# Three depth layers produce a long, low sea of cloud rather than nine
			# identical white rocks. Back layer is cooler and dimmer.
			for layer in 3:
				var z := -48.0-float(layer)*24.0
				var count := 8+layer*2
				for i in count:
					var x := -size.x*.52 + size.x*1.04*float(i)/float(maxi(1,count-1))
					var y := size.y*(.20+.11*float((i+layer)%3)) + float(layer)*18.0
					var cw := size.x*(.16-.018*float(layer))*(.86+.08*float(i%3))
					var ch := size.y*(.46-.06*float(layer))
					m.gem(Vector3(x,y,z),Vector3(cw,ch,42-float(layer)*8),
						Color("edf7f8").darkened(.035*float(layer)+.018*float(i%2)),9)
		_:
			push_warning("No 3D prop recipe: "+kind)
			m.gem(Vector3(0,8,0),Vector3(20,16,20),stone,5)

static func instance(kind: String, size: Vector2 = Vector2(40,40)) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh=mesh(kind,size)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
