class_name LevelBuilder
extends Node2D
## Instantiates whichever stage Stage says we are playing.
##
## Static geometry (terrain, decor, checkpoints, the goal) is built once.
## Everything that can be killed, tripped, opened or moved lives under a single
## "Dynamic" node, so a checkpoint reset is "free that node and build it again".

const BlackHoleChaserScript = preload("res://src/entities/enemies/black_hole_chaser.gd")
const SkyPursuerScript = preload("res://src/entities/enemies/sky_pursuer.gd")
const ThornmiteScript = preload("res://src/entities/enemies/thornmite.gd")

var runner: Runner = null
## Needed before build(): which player this screen belongs to decides what the
## veils hide, and the terrain is filtered on the way in.
var input_hub: InputHub = null

var _terrain: Node2D = null
var _decor: Node2D = null
var _dynamic: Node2D = null
var _static_root: Node2D = null
var _veils: VeilField = null

func build() -> void:
	_static_root = Node2D.new()
	_static_root.name = "Static"
	add_child(_static_root)

	# Before anything it might have to hide.
	_veils = VeilField.new()
	_veils.name = "Veils"
	_veils.veils = Stage.veils()
	_veils.hub = input_hub
	_veils.runner = runner
	add_child(_veils)

	_terrain = preload("res://src/render/terrain.gd").new()
	_static_root.add_child(_terrain)
	# Two lists, on purpose, and they are meant to be read together: the veil
	# filters what is PAINTED, and the line under it builds what is COLLIDED
	# WITH out of the unfiltered stage data. Hidden ground is still ground.
	_veils.take_terrain(_terrain, Stage.ground())
	_build_ground_bodies()

	_decor = preload("res://src/render/decor.gd").new()
	_decor.items = Stage.decor()
	_static_root.add_child(_decor)

	_build_checkpoints()
	_build_goal()
	_build_kill_plane()
	rebuild_dynamic()

func _build_ground_bodies() -> void:
	var body := StaticBody2D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	var solids: Array[Rect2] = Stage.ground()
	solids.append_array(Stage.solid_decor())
	for rect in solids:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.position + rect.size * 0.5
		body.add_child(shape)
	_static_root.add_child(body)

func _build_checkpoints() -> void:
	var points := Stage.checkpoints()
	for i in points.size():
		var cp := Checkpoint.new()
		cp.index = i + 1
		cp.global_position = points[i]
		_static_root.add_child(cp)

func _build_goal() -> void:
	var goal := Goal.new()
	goal.global_position = Stage.goal()
	_static_root.add_child(goal)

func _build_kill_plane() -> void:
	var pit := Hazard.new()
	pit.draw_spikes = false
	pit.span = Vector2(24000, 200)
	pit.global_position = Vector2(Stage.pit_centre_x(), Stage.kill_y() + 100.0)
	_static_root.add_child(pit)

func rebuild_dynamic() -> void:
	if _dynamic != null and is_instance_valid(_dynamic):
		_dynamic.free()
	_dynamic = Node2D.new()
	_dynamic.name = "Dynamic"
	add_child(_dynamic)
	# Everything below is about to be replaced, so the old list of things to
	# veil goes with it. Registering here rather than inside the entities is
	# what keeps enemies, hazards and pickups from having to know they can be
	# hidden -- this is the one place that already knows what each node is.
	if _veils != null:
		_veils.forget_watched()

	for h in Stage.hazards():
		var hazard := Hazard.new()
		hazard.span = h["size"]
		hazard.global_position = h["pos"]
		_dynamic.add_child(hazard)
		_veil(hazard, Veil.HAZARDS)

	var enemy_id := 0
	for e in Stage.enemies():
		var node := _make_enemy(e)
		if node != null:
			node.global_position = e["pos"]
			node.net_id = enemy_id
			_dynamic.add_child(node)
			_veil(node, Veil.ENEMIES, true)
		enemy_id += 1

	for g in Stage.gimmicks():
		var node := _make_gimmick(g)
		if node != null:
			node.global_position = g["pos"]
			_dynamic.add_child(node)
			_veil(node, Veil.GIMMICKS, node is MovingPlatform)

	for c in Stage.coins():
		var coin := Coin.new()
		coin.runner = runner
		coin.global_position = c
		_dynamic.add_child(coin)
		_veil(coin, Veil.PICKUPS)

	var crystal_id := 0
	for c in Stage.crystals():
		if not GameState.crystals_taken.has(crystal_id):
			var crystal := Crystal.new()
			crystal.runner = runner
			crystal.net_id = crystal_id
			crystal.amount = Balance.CRYSTAL_GAUGE
			crystal.global_position = c
			_dynamic.add_child(crystal)
			_veil(crystal, Veil.PICKUPS)
		crystal_id += 1

	for sp in Stage.springs():
		var pad := Spring.new()
		pad.runner = runner
		pad.global_position = sp
		_dynamic.add_child(pad)
		_veil(pad, Veil.GIMMICKS)

	# A rebuild happens mid-fight, so the barricades have to be told which act
	# they have just been built into. Doing it here rather than in
	# Barricade._ready keeps the boss's state out of their constructor -- and
	# there is no ordering to get wrong, because the Keeper is already in the
	# tree by the time this runs.
	_settle_barricades()
	_settle_boss()

	Events.level_rebuilt.emit()

## A gate whose keeper is already dead has to be built open.
##
## Emitted here rather than where the Keeper was skipped, because enemies are
## built before gimmicks and the gate that is listening does not exist yet at
## that point.
var _reopen_gate: String = ""

func _settle_boss() -> void:
	if _reopen_gate.is_empty():
		return
	var id := _reopen_gate
	_reopen_gate = ""
	Events.switch_activated.emit(id)

## Stand down any barricade whose act has already passed.
func _settle_barricades() -> void:
	var act := 1
	for e in _dynamic.get_children():
		if e is Keeper:
			act = (e as Keeper).act()
			break
	for node in _dynamic.get_children():
		if node is Barricade:
			(node as Barricade).settle(act)

func _veil(node: Node2D, layer: String, moving: bool = false) -> void:
	if _veils != null:
		_veils.watch(node, layer, moving)

## The live veils, for main (the marks) and for the probes.
func veil_field() -> VeilField:
	return _veils

func _make_enemy(spec: Dictionary) -> Node2D:
	match String(spec.get("type", "")):
		"chaser":
			var c = BlackHoleChaserScript.new()
			c.runner = runner
			c.chase_speed = float(spec.get("speed", 360.0))
			c.activation_distance = float(spec.get("activation", 100.0))
			c.spawn_distance = float(spec.get("spawn_distance", 420.0))
			return c
		"sky_pursuer":
			var p = SkyPursuerScript.new()
			p.runner = runner
			p.wake_delay = float(spec.get("delay", 2.25))
			p.cruise_speed = float(spec.get("speed", 220.0))
			p.catchup_speed = float(spec.get("catchup", 520.0))
			p.stun_duration = float(spec.get("stun", 1.35))
			var direction: Vector2 = spec.get("direction", Stage.progress_direction())
			p.chase_direction = direction.normalized()
			return p
		"thornmite":
			var tm = ThornmiteScript.new()
			tm.runner = runner
			tm.patrol_half_width = float(spec.get("patrol", 140.0))
			return tm
		"walker":
			var w := Walker.new()
			w.patrol_half_width = float(spec.get("patrol", 110.0))
			# Unknown skins fall back to the default rather than drawing
			# nothing: a typo in level data should cost a wrong picture, not an
			# invisible enemy the runner still dies to.
			var skin := String(spec.get("skin", "walker"))
			w.skin = skin if Art.MANIFEST.has(skin) else "walker"
			return w
		"flyer":
			var f := Flyer.new()
			f.patrol_half_width = float(spec.get("patrol", 190.0))
			return f
		"shieldbearer":
			var sb := Shieldbearer.new()
			sb.runner = runner
			return sb
		"keeper":
			# Already beaten. A respawn rebuilds this whole layer, so without
			# this a runner who dies AFTER the Keeper falls -- to a shockwave
			# still travelling, most likely -- comes back to a fresh boss on
			# full health in front of a gate that has closed again.
			if GameState.boss_hp == 0:
				_reopen_gate = String(spec.get("gate", ""))
				return null
			var k := Keeper.new()
			k.runner = runner
			# The arena's edges and the gate it opens both come from the level
			# data rather than from constants in the boss, so a second arena
			# needs a second row here and no second boss.
			var home: Vector2 = spec.get("home", Vector2(-100000.0, 100000.0))
			k.home_min = home.x
			k.home_max = home.y
			k.opens_gate = String(spec.get("gate", ""))
			return k
		"turret":
			var t := Turret.new()
			t.aim_direction = spec.get("aim", Vector2.LEFT)
			t.burst = int(spec.get("burst", 3))
			t.runner = runner
			return t
	return null

func _make_gimmick(spec: Dictionary) -> Node2D:
	match String(spec.get("type", "")):
		"moving_platform":
			var m := MovingPlatform.new()
			m.span = spec.get("span", Vector2(150, 26))
			m.travel = spec.get("travel", Vector2(220, 0))
			return m
		"crumble":
			var c := CrumblingFloor.new()
			c.span = spec.get("span", Vector2(120, 40))
			return c
		"laser":
			var l := Laser.new()
			l.direction = spec.get("dir", Vector2.RIGHT)
			l.max_length = float(spec.get("length", 520.0))
			return l
		"switch":
			var s := ShootableSwitch.new()
			s.switch_id = String(spec.get("id", "gate_a"))
			s.hold_time = float(spec.get("hold", 6.0))
			s.sigil = int(spec.get("sigil", 0))
			return s
		"gate":
			var gate := Gate.new()
			gate.span = spec.get("span", Vector2(40, 190))
			gate.switch_id = String(spec.get("id", "gate_a"))
			gate.wants = int(spec.get("wants", 0))
			return gate
		"barricade":
			var wall := Barricade.new()
			wall.needed_act = int(spec.get("act", 1))
			return wall
		"updraft":
			var lift := Updraft.new()
			lift.runner = runner
			lift.span = spec.get("span", Vector2(150.0, 420.0))
			return lift
	return null

func reset_to_checkpoint() -> void:
	rebuild_dynamic()
