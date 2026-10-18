extends RefCounted
## Six playable theatre acts, using the original runner and guardian controls.
static func kill_y_value() -> float: return 1080.0
static func start_position() -> Vector2: return Vector2(40, 470)
static func stage_name_value() -> String: return "THE TRICKSTER PARADE"
static func stage_number_value() -> String: return "1-9"
static func objective_value() -> String: return TranslationServer.translate("金色の的で、仕掛けを道に")
static func painted_2d_value() -> bool: return true
static func ground_one_way(rect: Rect2) -> bool: return rect.size.y <= 48
static func ground() -> Array[Rect2]:
	return [Rect2(-900,500,1290,95), Rect2(680,500,250,95),
		Rect2(940,640,260,65), Rect2(1120,500,250,95), Rect2(1680,500,520,95),
		Rect2(2200,500,600,95), Rect2(2960,450,360,95),
		Rect2(3320,620,220,65), Rect2(3690,620,160,65), Rect2(4200,500,1240,95),
		Rect2(5500,540,220,95), Rect2(6230,235,440,95),
		Rect2(760,300,190,36), Rect2(1510,285,180,36), Rect2(1980,285,200,36),
		Rect2(2480,305,200,36), Rect2(3060,260,220,36), Rect2(3620,310,150,36),
		Rect2(4260,305,230,36), Rect2(4720,310,200,36), Rect2(5340,300,200,36),
		Rect2(5480,650,250,40), Rect2(6130,430,170,36),
		# A missed opening has a recovery route; the upper balconies reward
		# riding the machinery rather than simply running along the stalls.
		Rect2(430,700,190,36), Rect2(620,605,90,36),
		Rect2(1780,180,170,32), Rect2(4050,180,150,32),
		Rect2(5080,205,150,32), Rect2(6070,235,120,32)]
static func solid_decor() -> Array[Rect2]: return []
static func decor() -> Array[Dictionary]: return []
static func hazards() -> Array[Dictionary]: return []
static func veils() -> Array[Dictionary]: return []
static func crystals() -> Array[Vector2]: return []
static func springs() -> Array[Vector2]: return []
static func goal() -> Vector2: return Vector2(6510,180)
static func checkpoints() -> Array[Vector2]:
	# The final retry starts on the lower balcony, clear of the waiting crowd.
	return [Vector2(1170,470), Vector2(2230,470), Vector2(3340,590), Vector2(4260,470), Vector2(5505,620)]
static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	# Each arc points from an entrance towards a real deck or landing. Upper
	# strings are optional rewards, never a trail into an unsupported pit.
	for arc in [[150,460,50,0], [435,440,42,-24], [770,255,34,0],
		[1400,420,32,-32], [1795,135,34,0], [1995,240,34,0],
		[2450,260,40,0], [2760,330,42,-24], [3075,215,40,0],
		[3430,420,36,-25], [3780,310,36,-25], [4065,135,30,0],
		[4275,260,40,0], [4735,265,34,0], [5095,160,30,0],
		[5590,425,30,-28], [6065,175,35,0], [6330,190,40,0]]:
		for i in 4:
			out.append(Vector2(arc[0] + i * arc[2], arc[1] + i * arc[3]))
	return out
## Stagecraft and the route guide share one authored set of act boundaries.
static func acts() -> Array[Dictionary]:
	return [
		{"name":"FALSE ENTRANCE", "from":0, "to":1100, "sign":Vector2(160,240), "colour":Color("eab76b"),
			"hint":"金色の的を撃って、口の橋を開こう"},
		{"name":"BACKSTAGE", "from":1100, "to":2200, "sign":Vector2(1210,240), "colour":Color("71cebd"),
			"hint":"リフトで上へ。竹馬のひざを撃つと足場に"},
		{"name":"PARADE CROSSING", "from":2200, "to":3300, "sign":Vector2(2280,230), "colour":Color("eda07f"),
			"hint":"大砲の的を撃って、高い放物線で渡ろう"},
		{"name":"ACCORDION GAP", "from":3300, "to":4250, "sign":Vector2(3360,190), "colour":Color("b6a2ee"),
			"hint":"蛇腹に乗ってから撃つ。紙吹雪の風で次の舞台へ"},
		{"name":"SPOTLIGHT GALLERY", "from":4250, "to":5450, "sign":Vector2(4310,120), "colour":Color("e8cc7b"),
			"hint":"暗い人形は足場。猟犬を壁へ誘導しよう"},
		{"name":"SKY WHEEL FINALE", "from":5450, "to":6670, "sign":Vector2(5510,100), "colour":Color("87cdda"),
			"hint":"月を下ろして観覧車へ。的を撃つと止められる"},
	]
static func zones() -> Array[Dictionary]:
	return acts()
static func enemies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for wave in [{"x":-740,"y":474,"n":28,"wake":220,"bounds":Vector2(-800,900)},
		{"x":2340,"y":474,"n":18,"wake":2180,"bounds":Vector2(2210,2750)},
		{"x":3370,"y":474,"n":14,"wake":3280,"bounds":Vector2(3330,3650)},
		{"x":5520,"y":510,"n":12,"wake":5430,"spacing":14,"bounds":Vector2(5500,5740)}]:
		for i in int(wave.n):
			out.append({"type":"parade_gremlin", "pos":Vector2(wave.x + i * int(wave.get("spacing",22)), wave.y),
				"speed":135 + i % 4 * 15, "dir":1, "wake":float(wave.wake), "bounds":wave.bounds, "large":i % 12 == 0})
	for row in [["mimic",840,468,680,930], ["stilt",1770,415,1700,2110], ["spider",1570,150,1400,1850],
		["drummer",2540,466,2330,2750], ["imp",2740,466,2680,2770], ["balloon",3590,345,3400,3700],
		["acrobat",3990,220,3840,4170], ["shadow",4560,450,4500,4730], ["hound",5060,474,4930,5330],
		["twins",4850,466,4740,5150], ["manager",6360,167,6300,6390]]:
		out.append({"type":"parade_actor", "kind":row[0], "pos":Vector2(row[1],row[2]), "bounds":Vector2(row[3],row[4]), "dir":1})
	for i in 6:
		out.append({"type":"parade_gremlin", "pos":Vector2(1860 + i*18,474), "speed":80,"dir":1,"wake":1200.0,"bounds":Vector2(1800,2080)})
	return out
static func gimmicks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in [["mask",535,500,300,24,0,-155], ["scenery",805,500,200,24,0,-240], ["trapdoors",1040,500,220,24,0,-95],
		["curtain",1480,500,220,24,0,-130], ["bell",1770,180,180,24,0,0], ["magnet",1940,160,180,24,0,0],
		["turntable",2400,500,260,24,0,-95], ["cannon",2720,500,140,24,0,-100], ["conveyor",3120,425,330,24,0,-100],
		["accordion",3510,500,330,24,0,-105], ["vent",3830,560,180,24,0,-65], ["balcony",4070,400,350,24,0,-85],
		["spot",4430,220,200,24,0,0], ["mirror",4910,500,180,24,0,-130], ["breakaway",5230,500,75,58,0,-155],
		["wheel",5930,355,160,24,0,0], ["moon",5610,510,310,24,0,-120], ["fireworks",6200,430,270,24,0,-120]]:
		out.append({"type":"parade_device", "kind":row[0], "id":"act_" + row[0], "pos":Vector2(row[1],row[2]),
			"span":Vector2(row[3],row[4]), "target":Vector2(row[5],row[6])})
	# Optional balcony routes: a lift, a cannon catch and two quick steps.
	out.append({"type":"moving_platform", "pos":Vector2(1700,270), "span":Vector2(120,24),
		"travel":Vector2(250,-95), "speed":100.0, "one_way":true})
	out.append({"type":"moving_platform", "pos":Vector2(2850,345), "span":Vector2(110,24),
		"travel":Vector2(120,-30), "speed":80.0, "one_way":true})
	for at in [Vector2(3910,275), Vector2(4940,260)]:
		out.append({"type":"crumble", "pos":at, "span":Vector2(100,24), "one_way":true})
	return out
