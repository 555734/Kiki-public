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
## The co-op run's sky crows and gate key. The versus circuit is cut from 1-1
## but races to a finish of its own, so it builds neither.
var co_op_extras: bool = true
## Needed before build(): which player this screen belongs to decides what the
## veils hide, and the terrain is filtered on the way in.
var input_hub: InputHub = null

var _terrain: Node2D = null
var _decor: Node2D = null
var _dynamic: Node2D = null
var _static_root: Node2D = null
var _veils: VeilField = null
var _cave_enemies: Array[CaveEnemy] = []
var _cave_traps: Array[CaveTrap] = []
var _cave_wake_timer: Timer = null

func build() -> void:
	if Stage.is_parade(): ParadeArt.warm()
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
	if Stage.water_y() != INF:
		_build_water()

	_build_checkpoints()
	_build_goal()
	_build_kill_plane()
	rebuild_dynamic()
	if Stage.is_cave():
		_cave_wake_timer = Timer.new()
		_cave_wake_timer.wait_time = 0.1
		_cave_wake_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
		_cave_wake_timer.timeout.connect(_refresh_cave_activity)
		add_child(_cave_wake_timer)
		_cave_wake_timer.start()

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
		# A vertical platformer needs pass-through ledges: the runner may jump
		# through stone from below and land on its top on the way down.
		shape.one_way_collision = Stage.ground_is_one_way(rect)
		body.add_child(shape)
	_static_root.add_child(body)

## The open sea of 1-4: drawn after the decor so the rocks and pier posts
## stand in it, with foam wherever a beach or a footing meets the water.
func _build_water() -> void:
	var sea := preload("res://src/render/sea_water.gd").new()
	sea.name = "PoisonWater" if Stage.is_swamp() else "Sea"
	sea.poison = Stage.is_swamp()
	sea.water_y = Stage.water_y()
	var shore := PackedFloat32Array()
	var solids: Array[Rect2] = Stage.ground()
	solids.append_array(Stage.solid_decor())
	for r in solids:
		shore.append(r.position.x)
		shore.append(r.end.x)
	sea.shore_x = shore
	_static_root.add_child(sea)

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
	_cave_enemies.clear()
	_cave_traps.clear()
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
		hazard.draw_spikes = bool(h.get("draw_spikes", true))
		hazard.global_position = h["pos"]
		_dynamic.add_child(hazard)
		_veil(hazard, Veil.HAZARDS)

	var enemy_id := 0
	for e in Stage.enemies():
		var node := _make_enemy(e)
		if node != null:
			node.global_position = e["pos"]
			node.net_id = enemy_id
			if node is CaveEnemy:
				node.runner = runner
				_cave_enemies.append(node)
			_dynamic.add_child(node)
			_veil(node, Veil.ENEMIES, true)
		enemy_id += 1

	# Crows over the course come after the listed enemies, so their net_ids
	# continue the same numbering on both devices.
	var crow_i := 0
	for p in (Stage.sky_crows() if co_op_extras else []):
		var crow := SkyCrow.new()
		crow.global_position = p
		crow.net_id = enemy_id
		crow.phase_offset = float(crow_i) * 1.7
		crow.patrol = 200.0 + float(crow_i % 3) * 40.0
		_dynamic.add_child(crow)
		_veil(crow, Veil.ENEMIES, true)
		enemy_id += 1
		crow_i += 1

	if co_op_extras and Stage.needs_key() and not GameState.has_key:
		var key := StageKey.new()
		key.runner = runner
		key.global_position = Stage.key_position()
		_dynamic.add_child(key)
		_veil(key, Veil.PICKUPS)

	for g in Stage.gimmicks():
		var node := _make_gimmick(g)
		if node != null:
			node.global_position = g["pos"]
			configure_gimmick(node, g)
			_dynamic.add_child(node)
			if node is CaveTrap:
				_cave_traps.append(node)
			_veil(node, Veil.GIMMICKS, node is MovingPlatform)

	for c in Stage.coins():
		var coin := Coin.new()
		coin.runner = runner
		coin.global_position = c
		_dynamic.add_child(coin)
		_veil(coin, Veil.PICKUPS)

	# Crystals only ever refilled the guardian's gauge, and the gauge is gone,
	# so they are no longer placed. The data stays for the tuning notes.
	var crystal_id := 0
	for c in (Stage.crystals() if Balance.COST_PLATFORM > 0.0 else []):
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
	_refresh_cave_activity()

	Events.level_rebuilt.emit()

## The cave is much longer than the visible area. A single timer checks authored
## actors ten times a second, instead of simulating every distant one at 60 Hz.
func _refresh_cave_activity() -> void:
	if (_cave_enemies.is_empty() and _cave_traps.is_empty()) \
			or runner == null or not is_instance_valid(runner):
		return
	var camera := get_viewport().get_camera_2d()
	var centre_y := runner.global_position.y
	var half_view_y := 750.0
	if camera != null:
		centre_y = camera.global_position.y
		half_view_y = get_viewport().get_visible_rect().size.y * 0.5 / camera.zoom.y
	for enemy in _cave_enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		# Include patrol travel and one timer interval of runner movement beyond
		# the screen, so a moving enemy is active before it can enter the view.
		# Never on the guest's device: there the host moves every enemy
		# (ClientSession switched them off), and switching them back on made
		# each one walk its own patrol as well -- the guest saw it somewhere
		# other than where it hit the runner.
		var near := Clock.is_host and absf(enemy.spawn_position.y - centre_y) <= \
			half_view_y + 850.0
		if enemy.is_physics_processing() != near:
			enemy.set_physics_process(near)
	for trap in _cave_traps:
		if not is_instance_valid(trap) or trap.is_queued_for_deletion():
			continue
		var near := absf(trap.global_position.y - centre_y) <= \
			half_view_y + trap.travel + 180.0
		if trap.is_physics_processing() != near:
			trap.set_physics_process(near)

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

## Every enemy type a stage spec can name; _make_enemy builds exactly these.
## Listed so a typo in a stage file is an error rather than an enemy that is
## silently not there -- see unknown_types().
const ENEMY_TYPES: Array[String] = [
	"cave_enemy", "desert_enemy", "chaser", "sky_pursuer", "thornmite", "walker",
	"flyer", "shieldbearer", "keeper", "mine", "seedling", "golem", "turret",
	"parade_gremlin", "parade_actor",
]

## Spec types the builder does not know, as "enemy:<type>" / "gimmick:<type>".
## Empty for a stage that builds everything it lists.
static func unknown_types(enemies: Array, gimmicks: Array) -> Array[String]:
	var out: Array[String] = []
	for spec in enemies:
		var type := String(spec.get("type", ""))
		if not ENEMY_TYPES.has(type):
			out.append("enemy:" + type)
	for spec in gimmicks:
		var type := String(spec.get("type", ""))
		if not GIMMICKS.has(type):
			out.append("gimmick:" + type)
	return out

func _make_enemy(spec: Dictionary) -> Node2D:
	var type := String(spec.get("type", ""))
	if not ENEMY_TYPES.has(type):
		push_error("Stage %s: unknown enemy type '%s' at %s" % [Stage.stage_number(), type, spec.get("pos")])
		return null
	match type:
		"parade_actor": return ParadeActor.from_spec(spec, runner)
		"parade_gremlin":
			var gremlin := ParadeGremlin.new()
			gremlin.runner = runner
			gremlin.speed = float(spec.get("speed", 245.0))
			gremlin.direction = int(spec.get("dir", 1))
			gremlin.wake_x = float(spec.get("wake", 200.0))
			gremlin.bounds = spec.get("bounds", Vector2(-1200, 1550))
			gremlin.large = bool(spec.get("large", false))
			gremlin.kill_y = Stage.kill_y()
			return gremlin
		"cave_enemy":
			var cave := CaveEnemy.new()
			cave.kind = String(spec.get("kind", "burrower"))
			cave.patrol_half_width = float(spec.get("patrol", 100.0))
			cave.wander = spec.get("wander", Vector2.ZERO)
			cave.dart = float(spec.get("dart", 1.3))
			return cave
		"desert_enemy":
			var d := DesertEnemy.new()
			d.kind = String(spec.get("kind", "scarab"))
			d.patrol_half_width = float(spec.get("patrol", 150.0))
			return d
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
			p.activation_distance = float(spec.get("activation", 0.0))
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
		"mine":
			var mine := SkyMine.new()
			mine.bob = spec.get("bob", Vector2(0, 40))
			mine.period = float(spec.get("period", 3.2))
			mine.phase_offset = float(spec.get("phase", 0.0))
			mine.wander = spec.get("wander", Vector2.ZERO)
			mine.dart = float(spec.get("dart", 1.4))
			return mine
		"seedling":
			var sprout := SkySeedling.new()
			sprout.reach = spec.get("reach", Vector2(150, 60))
			sprout.period = float(spec.get("period", 5.0))
			sprout.phase_offset = float(spec.get("phase", 0.0))
			return sprout
		"golem":
			var golem := SkyGolem.new()
			golem.patrol = float(spec.get("patrol", 120.0))
			golem.period = float(spec.get("period", 6.0))
			golem.phase_offset = float(spec.get("phase", 0.0))
			return golem
		"turret":
			var t := Turret.new()
			t.aim_direction = spec.get("aim", Vector2.LEFT)
			t.burst = int(spec.get("burst", 3))
			t.runner = runner
			return t
	return null

## What the stage decides about a piece, rather than the piece itself. Pieces
## that can be stood on take their pass-through from the spec, else from the
## stage default; the piece never asks which stage it is in. Runs before the
## node enters the tree, so its _ready already sees the answer.
static func configure_gimmick(node: Node2D, spec: Dictionary) -> void:
	if "one_way" in node:
		node.one_way = bool(spec.get("one_way", Stage.platforms_one_way()))

## Every gimmick type a stage spec can name. Each script parses its own spec
## in from_spec(); adding a type is a line here and a from_spec there.
const GIMMICKS := {
	"parade_device": preload("res://src/entities/gimmicks/parade_device.gd"),
	"parade_machine": preload("res://src/entities/gimmicks/parade_machine.gd"),
	"coastal_hazard": preload("res://src/entities/gimmicks/coastal_hazard.gd"),
	"volcanic_hazard": preload("res://src/entities/gimmicks/volcanic_hazard.gd"),
	"moving_platform": preload("res://src/entities/gimmicks/moving_platform.gd"),
	"cave_trap": preload("res://src/entities/gimmicks/cave_trap.gd"),
	"switch_bridge": preload("res://src/entities/gimmicks/switch_bridge.gd"),
	"trick_pad": preload("res://src/entities/gimmicks/trick_pad.gd"),
	"clock_hand": preload("res://src/entities/gimmicks/clock_hand_bridge.gd"),
	"gear_wheel": preload("res://src/entities/gimmicks/gear_wheel.gd"),
	"tower_trap": preload("res://src/entities/gimmicks/tower_trap.gd"),
	"blink": preload("res://src/entities/gimmicks/blink_block.gd"),
	"conveyor": preload("res://src/entities/gimmicks/conveyor.gd"),
	"warp": preload("res://src/entities/gimmicks/warp_gate.gd"),
	"warp_exit": preload("res://src/entities/gimmicks/warp_gate.gd"),
	"crumble": preload("res://src/entities/gimmicks/crumbling_floor.gd"),
	"laser": preload("res://src/entities/gimmicks/laser.gd"),
	"switch": preload("res://src/entities/gimmicks/shootable_switch.gd"),
	"gate": preload("res://src/entities/gimmicks/gate.gd"),
	"barricade": preload("res://src/entities/gimmicks/barricade.gd"),
	"updraft": preload("res://src/entities/gimmicks/updraft.gd"),
}

func _make_gimmick(spec: Dictionary) -> Node2D:
	var type := String(spec.get("type", ""))
	var script: Script = GIMMICKS.get(type)
	if script == null:
		push_error("Stage %s: unknown gimmick type '%s' at %s" % [Stage.stage_number(), type, spec.get("pos")])
		return null
	return script.from_spec(spec, runner)

func reset_to_checkpoint() -> void:
	rebuild_dynamic()
