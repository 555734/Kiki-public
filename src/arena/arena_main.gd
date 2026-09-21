extends Node2D
## The coin battle, playable on one machine.
##
## docs/coin-battle-plan.md P1: "その場で四人で遊べる最小版". This is the whole
## view layer -- it owns the window, the camera, the device polling and the
## painting, and it owns none of the rules. Everything that decides anything is
## in ArenaMatchState, which is why the rules probe can run ten thousand ticks of
## a match with this file absent.
##
## Run it directly (`res://src/arena/arena_main.tscn`). It is deliberately NOT
## wired into the start screen: `run/main_scene` stays main.tscn and the
## cooperative launch path is untouched, because the plan puts menu integration
## in P5 and a half-finished mode on the menu is how a prototype becomes a
## promise (7.1, 12).
##
## Keys, for the one keyboard seat: A/D or arrows to move, Space or W to jump,
## J or Shift to swing, R to rematch, Escape to leave.

## The whole arena is 960x620 and the camera never moves, so this is a constant
## rather than a fit computed from the viewport. Centred a little above the main
## floor, because the floor is at y=120 and the top shelf at y=-110: framing on
## zero would leave the sky in shot and crop the feet.
const CAMERA_CENTRE := Vector2(0.0, -60.0)

# Grey box, as the plan asks for (6.1). Nothing here is art; it is there to be
# measured against, and a grey box is honest about that.
const COL_BACKDROP := Color(0.09, 0.10, 0.13)
const COL_FLOOR := Color(0.38, 0.40, 0.45)
const COL_FLOOR_EDGE := Color(0.58, 0.61, 0.67)
const COL_BLAST := Color(0.75, 0.25, 0.28, 0.35)
const COL_COIN := Color(1.0, 0.82, 0.29)
const COL_COIN_EDGE := Color(0.62, 0.45, 0.10)
const COL_SPAWN_HINT := Color(1.0, 0.82, 0.29, 0.28)

var match_state: ArenaMatchState = null
var stage: ArenaStage = null
var input: ArenaInput = null
var hud: Node2D = null

var _camera: Camera2D = null
var _prev_phase: int = -1
## Printed at every match start, so a match that goes wrong can be replayed
## through the probe with the same number.
var _seed: int = 0

func _ready() -> void:
	stage = ArenaStage.from_data()
	input = ArenaInput.new()
	Input.joy_connection_changed.connect(_on_joy_changed)

	_camera = Camera2D.new()
	_camera.position = CAMERA_CENTRE
	_camera.zoom = Vector2.ONE
	add_child(_camera)
	_camera.make_current()

	hud = preload("res://src/arena/arena_hud.gd").new()
	add_child(hud)

	match_state = ArenaMatchState.new()
	hud.arena = self
	_start_match()
	if Balance.USE_3D_RUNNER:
		add_child(preload("res://src/render/three/character_view.gd").new())

func _on_joy_changed(_device: int, _connected: bool) -> void:
	input.assign_devices()

## A fresh match. The seed is new every time so respawn choices and contested
## pickups are not the same four decisions in every match, and it is logged so
## any one match can be reproduced.
func _start_match() -> void:
	_seed = int(Time.get_ticks_usec() & 0x7fffffff)
	match_state.setup(stage, _seed)
	match_state.begin_countdown()
	_prev_phase = match_state.phase
	print("arena: match seed %d" % _seed)

func _physics_process(_delta: float) -> void:
	var intents := input.poll()

	if match_state.phase == ArenaMatchState.Phase.RESULTS:
		if input.take_rematch():
			_start_match()
		queue_redraw()
		hud.queue_redraw()
		return

	match_state.tick_match(intents)

	# The whistle. A jump pressed while the countdown was running must not fire
	# the instant the match starts, so the presses made before it are marked as
	# already spent. MotorState counts presses rather than reading a level
	# precisely so that a press can be accounted for like this.
	if _prev_phase == ArenaMatchState.Phase.COUNTDOWN \
			and match_state.phase == ArenaMatchState.Phase.PLAYING:
		_consume_pre_whistle_presses()
	_prev_phase = match_state.phase

	queue_redraw()
	hud.queue_redraw()

func _consume_pre_whistle_presses() -> void:
	for i in range(match_state.fighters.size()):
		if i >= input.seats.size():
			continue
		var seat: ArenaInput.Seat = input.seats[i]
		match_state.fighters[i].motor.jump_press_seq = seat.jump_seq
		match_state.fighters[i].combat.attack_seq = seat.attack_seq

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit(0)

# ---------------------------------------------------------------------- paint
func _draw() -> void:
	_backdrop()
	_blast_lines()
	_floors()
	_spawn_hints()
	_coins()
	_fighters()

func _backdrop() -> void:
	if Balance.USE_3D: return
	draw_rect(Rect2(CAMERA_CENTRE - Vector2(680.0, 400.0),
		Vector2(1360.0, 800.0)), COL_BACKDROP)

## Where the arena ends. Drawn because "I did not know I was that close to the
## edge" is the least interesting way to lose a coin.
func _blast_lines() -> void:
	var top := -400.0
	var bottom := ArenaStageData.BLAST_BOTTOM
	draw_line(Vector2(ArenaStageData.BLAST_LEFT, top),
		Vector2(ArenaStageData.BLAST_LEFT, bottom), COL_BLAST, 3.0)
	draw_line(Vector2(ArenaStageData.BLAST_RIGHT, top),
		Vector2(ArenaStageData.BLAST_RIGHT, bottom), COL_BLAST, 3.0)
	draw_line(Vector2(ArenaStageData.BLAST_LEFT, bottom),
		Vector2(ArenaStageData.BLAST_RIGHT, bottom), COL_BLAST, 3.0)

func _floors() -> void:
	if Balance.USE_3D: return
	for b in stage.boxes():
		draw_rect(b, COL_FLOOR)
		draw_rect(b, COL_FLOOR_EDGE, false, 1.5)

## The next scheduled coin, marked a couple of seconds early (3.2). Everyone
## sees it at the same moment, which is the point: the run for it should be a
## race, not a surprise.
func _spawn_hints() -> void:
	var due := match_state.next_spawn_in()
	if due < 0 or due > ArenaRules.SPAWN_WARNING_TICKS:
		return
	var points := ArenaStageData.coin_spawn_points()
	var idx := mini(match_state.ledger.spawned_count, points.size() - 1)
	var at: Vector2 = points[idx]
	var pulse := 1.0 - float(due) / float(ArenaRules.SPAWN_WARNING_TICKS)
	draw_arc(at, 12.0 + 10.0 * (1.0 - pulse), 0.0, TAU, 20, COL_SPAWN_HINT, 2.0)

func _coins() -> void:
	for c in match_state.ledger.coins:
		if c.state != ArenaCoin.State.WORLD:
			continue
		var alpha := 1.0
		# A coin nobody has taken starts blinking before it is recycled, so it
		# is clear it is about to move rather than having vanished (3.4).
		var age := match_state.tick - c.world_since
		var left := ArenaRules.COIN_STALE_TICKS - age
		if left <= ArenaRules.COIN_BLINK_TICKS:
			alpha = 0.35 + 0.65 * absf(sin(float(left) * 0.25))
		var fill := COL_COIN
		fill.a = alpha
		if not Balance.USE_3D:
			draw_circle(c.position, 7.0, fill)
			draw_arc(c.position, 7.0, 0.0, TAU, 16, COL_COIN_EDGE, 1.5)
		# Locked out: nobody may take it yet.
		if match_state.tick < c.pickup_tick:
			draw_arc(c.position, 11.0, 0.0, TAU, 16,
				Color(1.0, 1.0, 1.0, 0.35), 1.0)

func _fighters() -> void:
	for f in match_state.fighters:
		if not f.alive:
			_ghost(f)
			continue
		_body(f)
		_hitbox(f)

## A blasted-out fighter: the respawn clock, drawn over the last place they
## stood safely. Not over the respawn point, because that is picked at the
## moment they return and is not known yet (5). Drawing nothing at all would
## leave a player with no idea how long they are out for.
func _ghost(f: ArenaFighter) -> void:
	var col: Color = ArenaRules.TEAM_COLOURS[f.team_id]
	col.a = 0.22
	var at := f.last_safe_drop
	draw_rect(Rect2(at - ArenaRules.BODY_SIZE * 0.5, ArenaRules.BODY_SIZE),
		col, false, 1.5)
	var frac := 1.0 - float(f.respawn_in) / float(ArenaRules.RESPAWN_TICKS)
	draw_arc(at, 20.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 20, col, 3.0)

func _body(f: ArenaFighter) -> void:
	var col: Color = ArenaRules.TEAM_COLOURS[f.team_id]
	# Untouchable: flash rather than fade, so it reads at a glance and cannot be
	# mistaken for a fighter who is simply far away.
	if f.combat.invulnerable():
		var flash := f.combat.respawn_invuln if f.combat.respawn_invuln > 0 \
			else f.combat.hit_invuln
		col.a = 0.45 if (flash / 4) % 2 == 0 else 0.9
	var body := f.body()
	if not Balance.USE_3D_RUNNER:
		DrawUtil.rounded_rect(self, body, 7.0, col)
		draw_rect(body, ArenaRules.MATE_TRIM[f.actor_id % 2], false, 2.0)
	else:
		draw_arc(f.centre()+Vector2(0,ArenaRules.BODY_SIZE.y*.5),16,0,TAU,20,
			ArenaRules.MATE_TRIM[f.actor_id%2],2.0)

	# Which way a swing would go.
	var eye := f.centre() + Vector2(float(f.motor.facing) * 8.0, -12.0)
	if not Balance.USE_3D_RUNNER: draw_circle(eye, 3.0, Color(0.06, 0.07, 0.10))

	# Pressure. Not HP and not the coin count -- it only says how far the next
	# hit will send them (4.2).
	var p := f.combat.pressure / ArenaRules.PRESSURE_MAX
	if p > 0.0:
		var bar := Rect2(body.position + Vector2(0.0, body.size.y + 4.0),
			Vector2(body.size.x * p, 3.0))
		draw_rect(bar, Color(1.0, 0.45, 0.35, 0.9))

	if f.combat.stunned():
		draw_arc(f.centre(), 26.0, 0.0, TAU, 18,
			Color(1.0, 0.9, 0.4, 0.55), 2.0)

## The live hitbox, while it is live. Showing it is worth more than hiding it:
## the whole fight is about whether 8 startup frames were enough warning.
func _hitbox(f: ArenaFighter) -> void:
	if f.combat.phase == ArenaCombat.Phase.STARTUP:
		var tell := Rect2(f.centre() + Vector2(float(f.combat.attack_dir) * 18.0,
			-ArenaRules.ATTACK_RISE) - Vector2(6.0, 6.0), Vector2(12.0, 12.0))
		draw_rect(tell, Color(1.0, 1.0, 1.0, 0.30))
		return
	var hb := ArenaCombat.hitbox(f.combat, f.centre())
	if hb.size == Vector2.ZERO:
		return
	draw_rect(hb, Color(1.0, 0.95, 0.70, 0.30))
	draw_rect(hb, Color(1.0, 0.95, 0.70, 0.85), false, 2.0)
