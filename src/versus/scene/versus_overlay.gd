class_name VersusOverlay
extends Node2D
## What the versus arena draws in world space above the scenery: loose stars,
## the guardians' platforms, the ring at each runner's feet and the pips of
## stars carried over their heads.
##
## A node of its own rather than the arena's _draw: drawn on the arena itself
## these sat underneath its children -- the level's ground, trees and
## signposts -- and a star behind a tree was a star nobody could see.

const COL_COIN := Color(1.0, 0.82, 0.29)
const COL_COIN_EDGE := Color(0.62, 0.45, 0.10)
## A loose star's drawn radius. Big enough to read across a phone screen.
const STAR_RADIUS: float = 44.0

var arena = null

func _init() -> void:
	name = "Overlay"
	z_index = 20

func _draw() -> void:
	_builds()
	_markers()
	_coins()
	_heads()

## A guardian's construct, in its own team's colour. Read off the shared team
## palette rather than restated, so a platform is unmistakably one side's.
## Drawn nearly solid: the first version was translucent and vanished against
## 1-1's bright grass, which made a platform something you found by walking
## into it.
func build_fill(team: int) -> Color:
	var c: Color = arena.colour_of(team)
	return Color(c.r, c.g, c.b, 0.80)

func build_edge(team: int) -> Color:
	var c: Color = arena.colour_of(team)
	return Color(minf(1.0, c.r + 0.35), minf(1.0, c.g + 0.35),
		minf(1.0, c.b + 0.35), 1.0)

## How many stars each runner is carrying, over their head. Pips, not a number:
## what you need at a glance is "more than them". World space, which is why it
## lives here and not in the HUD.
func _heads() -> void:
	for i in range(arena.sides):
		var held: int = arena.held_by(i)
		if held <= 0:
			continue
		var centre: Vector2 = arena.runners[i].global_position
		var y := centre.y - Balance.RUNNER_SIZE.y * 0.5 - 18.0
		var pitch := 18.0
		var x0 := centre.x - pitch * float(held - 1) * 0.5
		for k in range(held):
			_star_shape(Vector2(x0 + pitch * float(k), y), 9.0, COL_COIN)

func _star_shape(at: Vector2, r: float, fill: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(10):
		var rr := r if k % 2 == 0 else r * 0.45
		var a := -PI * 0.5 + float(k) * TAU / 10.0
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, COL_COIN_EDGE, maxf(1.5, r * 0.12))

func _builds() -> void:
	var built: Array[Rect2] = arena.platforms.built
	var owners: Array[int] = arena.platforms.build_owner
	for i in range(built.size()):
		var team: int = VersusRoster.side_of_in(arena.room_mode, owners[i]) \
			if i < owners.size() else 0
		# A dark outline under the bright one. Team A's colour is a sky blue and
		# 1-1's sky is behind half the arena, so a platform drawn in it alone
		# disappeared into the background -- something you found by walking into
		# it rather than by looking.
		var box := Rect2(arena._near(built[i].position), built[i].size)
		draw_rect(box.grow(2.0), Color(0.06, 0.07, 0.10, 0.85), false, 5.0)
		draw_rect(box, build_fill(team))
		draw_rect(box, build_edge(team), false, 3.0)
		# A highlight along the top, so which side of it you can stand on is
		# obvious from across the arena.
		draw_line(box.position + Vector2(0.0, 1.5),
			box.position + Vector2(box.size.x, 1.5),
			Color(1, 1, 1, 0.75), 3.0)

func _markers() -> void:
	for i in range(arena.sides):
		if arena.lives.respawn_in[i] > 0:
			continue
		var at: Vector2 = arena.runners[i].global_position \
			+ Vector2(0.0, Balance.RUNNER_SIZE.y * 0.5)
		draw_arc(at, 17.0, 0.0, TAU, 20, build_edge(i), 3.0)

func _coins() -> void:
	var tick: int = arena.world_tick()
	for c in arena.coins():
		if int(c["state"]) != ArenaCoin.State.WORLD:
			continue
		var at: Vector2 = arena._near(c["position"])
		var fill := COL_COIN
		if c.has("world_since"):
			var left := VersusRules.STALE_TICKS - (tick - int(c["world_since"]))
			if left <= 90:
				fill.a = 0.35 + 0.65 * absf(sin(float(left) * 0.25))
		# With the 3D view up, the star is a model there; only the ring is ours.
		if arena._world_view == null:
			_star_shape(at, STAR_RADIUS, fill)
		if c.has("pickup_tick") and tick < int(c["pickup_tick"]):
			draw_arc(at, STAR_RADIUS + 4.0, 0.0, TAU, 20, Color(1, 1, 1, 0.45), 2.0)
