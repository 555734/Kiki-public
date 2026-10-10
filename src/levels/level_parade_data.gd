extends RefCounted
## Six playable theatre acts, using the original runner and guardian controls.
static func kill_y_value() -> float: return 1080.0
static func start_position() -> Vector2: return Vector2(40, 470)
static func stage_name_value() -> String: return "THE TRICKSTER PARADE"
static func stage_number_value() -> String: return "1-9"
static func objective_value() -> String: return "Shoot the brass latches. Turn the parade into a path."
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
		Rect2(5480,650,250,40), Rect2(6130,430,170,36)]
static func solid_decor() -> Array[Rect2]: return []
static func decor() -> Array[Dictionary]: return []
static func hazards() -> Array[Dictionary]: return []
static func veils() -> Array[Dictionary]: return []
static func crystals() -> Array[Vector2]: return []
static func springs() -> Array[Vector2]: return []
static func goal() -> Vector2: return Vector2(6510,180)
static func checkpoints() -> Array[Vector2]:
	return [Vector2(1170,470), Vector2(2230,470), Vector2(3340,590), Vector2(4260,470), Vector2(5540,510)]
static func coins() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for x in [800,1550,2030,2520,3100,3660,4300,4760,5390,6160,6370]: out.append(Vector2(x, 220))
	return out
static func zones() -> Array[Dictionary]:
	return [{"name":"FALSE ENTRANCE", "from":0, "to":1100}, {"name":"BACKSTAGE", "from":1100, "to":2200},
		{"name":"PARADE CROSSING", "from":2200, "to":3300}, {"name":"ACCORDION GAP", "from":3300, "to":4250},
		{"name":"SPOTLIGHT GALLERY", "from":4250, "to":5450}, {"name":"SKY WHEEL FINALE", "from":5450, "to":6670}]
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
	return out
