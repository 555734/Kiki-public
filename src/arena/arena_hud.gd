extends Node2D
## What the four players need to read while they play.
##
## docs/coin-battle-plan.md 4.4 lists it: the coins over each head, each team's
## total with the clock, all seven coins' whereabouts, and the result with a way
## straight back into another match. Nothing else -- no minimap, no damage
## numbers, no kill feed. The mode's question is whether seven coins are worth
## fighting over, and a HUD that answers other questions makes that harder to
## see, not easier.
##
## Drawn in WORLD coordinates, as a sibling of the arena under the same fixed
## camera. That is not laziness: the camera in this mode never moves (4.4 rules
## out follow, pan and scope), so world and screen differ by a constant, and
## coordinates that are already world-space are the ones the coins over a head
## need. A Control layer would mean maintaining a world-to-screen transform for
## the half of this file that tracks a fighter.

## The framing arena_main sets up: the camera sits at (0, -60) at zoom 1 in a
## 1280x720 viewport, so this is exactly what is on screen. Chrome is placed
## against these rather than against a viewport size, so the layout cannot drift
## from the camera.
##
## Worth stating rather than deriving, because the first version of this file had
## the top at -460 -- 40px above what the camera can see, which put the
## scoreboard and the coin strip off the screen entirely. Headless never calls
## _draw, so nothing but a render could have caught it.
const VIEW_LEFT: float = -640.0
const VIEW_RIGHT: float = 640.0
const VIEW_TOP: float = -420.0

const COL_INK := Color(0.93, 0.95, 0.98)
const COL_DIM := Color(0.62, 0.66, 0.73)
const COL_PANEL := Color(0.05, 0.06, 0.09, 0.80)
const COL_COIN := Color(1.0, 0.82, 0.29)
const COL_UNSPAWNED := Color(0.30, 0.32, 0.38)
const COL_RECYCLE := Color(0.55, 0.58, 0.66)

## Set by arena_main. Untyped because arena_main.gd has no class_name -- it is a
## scene root, not a library -- and naming it here would not typecheck anyway.
var arena: Node2D = null

func _draw() -> void:
	if arena == null or arena.match_state == null:
		return
	var m: ArenaMatchState = arena.match_state
	_scoreboard(m)
	_coin_strip(m)
	_heads(m)
	_seat_notices()
	if m.phase == ArenaMatchState.Phase.COUNTDOWN:
		_countdown(m)
	if m.phase == ArenaMatchState.Phase.OVERTIME:
		_overtime(m)
	if m.phase == ArenaMatchState.Phase.RESULTS:
		_result(m)

func _font() -> Font:
	return Art.font()

# ----------------------------------------------------------------- scoreboard
## Both totals and the clock, in one strip along the top. The totals are read
## from the ledger every frame; there is no counter here to fall out of step
## with the coins on screen (3.4).
func _scoreboard(m: ArenaMatchState) -> void:
	var font := _font()
	var a := m.score(ArenaMatchState.TEAM_A)
	var b := m.score(ArenaMatchState.TEAM_B)
	var panel := Rect2(Vector2(-250.0, VIEW_TOP + 18.0), Vector2(500.0, 54.0))
	draw_rect(panel, COL_PANEL)

	# Centred in equal columns at each end, rather than placed by eye: a score
	# reaching two digits must not walk towards the clock.
	draw_string(font, panel.position + Vector2(0.0, 40.0), "%d" % a,
		HORIZONTAL_ALIGNMENT_CENTER, 110.0, 40, ArenaRules.TEAM_COLOURS[0])
	draw_string(font, panel.position + Vector2(panel.size.x - 110.0, 40.0), "%d" % b,
		HORIZONTAL_ALIGNMENT_CENTER, 110.0, 40, ArenaRules.TEAM_COLOURS[1])

	# During the countdown this shows the match length, not the seconds left of
	# the countdown itself. ticks_left() answers about the phase it is in, which
	# is right; "0:01" in the clock slot next to a big "2" is not -- it reads as
	# a match about to end.
	var left := ArenaRules.MATCH_TICKS if m.phase == ArenaMatchState.Phase.COUNTDOWN \
		else m.ticks_left()
	var label := "%d:%02d" % [left / 3600, (left / 60) % 60]
	draw_string(font, panel.position + Vector2(180.0, 36.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, 140, 30, COL_INK)

	# The coins still loose. Without it, 3-3 with one coin on the floor and 3-3
	# with the seventh in somebody's hand look identical.
	var loose := m.ledger.count_in(ArenaCoin.State.WORLD)
	var pending := m.ledger.count_in(ArenaCoin.State.RECYCLE_PENDING) \
		+ m.ledger.count_in(ArenaCoin.State.UNSPAWNED)
	draw_string(font, panel.position + Vector2(180.0, 50.0),
		"%d loose · %d to come" % [loose, pending],
		HORIZONTAL_ALIGNMENT_CENTER, 140, 12, COL_DIM)

## All seven coins, always, in id order. The plan asks for this specifically
## (4.4) and it is the one readout that makes the ledger visible: seven icons
## that are always seven, whoever is holding what.
func _coin_strip(m: ArenaMatchState) -> void:
	var y := VIEW_TOP + 90.0
	var pitch := 26.0
	var x0 := -pitch * float(ArenaRules.COIN_COUNT - 1) * 0.5
	for i in range(m.ledger.coins.size()):
		var c: ArenaCoin.Record = m.ledger.coins[i]
		var at := Vector2(x0 + pitch * float(i), y)
		match c.state:
			ArenaCoin.State.UNSPAWNED:
				draw_arc(at, 8.0, 0.0, TAU, 16, COL_UNSPAWNED, 1.5)
			ArenaCoin.State.WORLD:
				draw_arc(at, 8.0, 0.0, TAU, 16, COL_COIN, 2.0)
			ArenaCoin.State.HELD:
				draw_circle(at, 8.0, ArenaRules.TEAM_COLOURS[m.team_of(c.owner)])
				draw_arc(at, 8.0, 0.0, TAU, 16, COL_COIN, 1.5)
			ArenaCoin.State.RECYCLE_PENDING:
				draw_arc(at, 8.0, 0.0, TAU, 16, COL_RECYCLE, 1.5)
				draw_line(at + Vector2(-4.0, 0.0), at + Vector2(4.0, 0.0),
					COL_RECYCLE, 1.5)

## How many each fighter is carrying, over their head. Pips rather than a
## number: at a glance you need "more than them", not the exact count, and four
## heads' worth of digits is four things to read (4.4).
func _heads(m: ArenaMatchState) -> void:
	for f in m.fighters:
		if not f.alive:
			continue
		var held := m.ledger.count_held_by(f.actor_id)
		if held <= 0:
			continue
		var top := f.centre().y - ArenaRules.BODY_SIZE.y * 0.5 - 12.0
		var pitch := 11.0
		var x0 := f.centre().x - pitch * float(held - 1) * 0.5
		for i in range(held):
			var at := Vector2(x0 + pitch * float(i), top)
			draw_circle(at, 4.0, COL_COIN)
			draw_arc(at, 4.0, 0.0, TAU, 10, Color(0.25, 0.18, 0.04, 0.9), 1.0)

## Which device each fighter is on. Only for seats nobody is holding, and only
## before the whistle -- during a match it is noise, but "why is player 3 not
## moving" needs an answer before the match starts, not after it.
func _seat_notices() -> void:
	var m: ArenaMatchState = arena.match_state
	if m.phase != ArenaMatchState.Phase.COUNTDOWN:
		return
	var font := _font()
	for f in m.fighters:
		var at := f.centre() + Vector2(0.0, -46.0)
		draw_string(font, at - Vector2(50.0, 0.0),
			arena.input.seat_label(f.actor_id),
			HORIZONTAL_ALIGNMENT_CENTER, 100, 12,
			COL_INK if arena.input.seats[f.actor_id].kind != ArenaInput.Kind.NONE
				else Color(1.0, 0.45, 0.4))

# -------------------------------------------------------------------- moments
func _countdown(m: ArenaMatchState) -> void:
	var left := m.ticks_left()
	var seconds := int(ceil(float(left) / 60.0))
	var label := "%d" % seconds if seconds > 0 else "GO"
	draw_string(_font(), Vector2(-160.0, -30.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, 320, 72, COL_INK)

## Overtime is won by holding a sole lead for two seconds, and losing the lead
## RESETS that clock rather than pausing it (3.1). A bar is the only way to show
## the difference; a number would look the same either way.
func _overtime(m: ArenaMatchState) -> void:
	var font := _font()
	draw_string(font, Vector2(-160.0, VIEW_TOP + 116.0), "OVERTIME",
		HORIZONTAL_ALIGNMENT_CENTER, 320, 20, COL_INK)
	var team := m.lead_team()
	if team < 0:
		draw_string(font, Vector2(-160.0, VIEW_TOP + 136.0), "level",
			HORIZONTAL_ALIGNMENT_CENTER, 320, 13, COL_DIM)
		return
	var track := Rect2(Vector2(-120.0, VIEW_TOP + 126.0), Vector2(240.0, 6.0))
	draw_rect(track, Color(0.20, 0.22, 0.27))
	var fill := track
	fill.size.x = track.size.x * m.lead_progress()
	draw_rect(fill, ArenaRules.TEAM_COLOURS[team])

func _result(m: ArenaMatchState) -> void:
	var font := _font()
	var panel := Rect2(Vector2(-220.0, -110.0), Vector2(440.0, 180.0))
	draw_rect(panel, COL_PANEL)
	draw_rect(panel, COL_DIM, false, 1.5)

	var headline := "DRAW"
	var tint := COL_INK
	if not m.draw and m.winner >= 0:
		headline = "TEAM %s WINS" % ("A" if m.winner == ArenaMatchState.TEAM_A else "B")
		tint = ArenaRules.TEAM_COLOURS[m.winner]
	draw_string(font, panel.position + Vector2(0.0, 56.0), headline,
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 34, tint)

	draw_string(font, panel.position + Vector2(0.0, 96.0),
		"%d  -  %d" % [m.score(ArenaMatchState.TEAM_A),
			m.score(ArenaMatchState.TEAM_B)],
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 26, COL_INK)

	draw_string(font, panel.position + Vector2(0.0, 134.0),
		"START or R for another  ·  Esc to leave",
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 14, COL_DIM)
	draw_string(font, panel.position + Vector2(0.0, 158.0),
		"seed %d" % m.seed_value,
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 11, COL_DIM)
