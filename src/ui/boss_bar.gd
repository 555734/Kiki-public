class_name BossBar
extends CanvasLayer
## The Keeper's six wounds, the act, and the shot clock on an open core.
##
## Only exists on 1-B (Main builds it when Stage.is_keeper()), and it shows the
## same three things to both players, which is the point. In every other stage
## the two of them are looking at different problems; here they are looking at
## one enemy, and a bar that only the guardian could see would mean the runner
## never finds out whether the bait worked.
##
## Six pips rather than a continuous bar. A continuous bar answers "roughly how
## much is left"; this fight's real question is "how many more times do we have
## to do this", and that is a countable number.

const PIP_W := 30.0
const PIP_H := 14.0
const GAP := 6.0

var keeper: Node2D = null

var _flash: float = 0.0
var _last_hp: int = -1

func _ready() -> void:
	layer = 9        # under the HUD (10+) and over the world
	var root := Control.new()
	root.name = "BossBarRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var painter := Painter.new()
	painter.bar = self
	painter.set_anchors_preset(Control.PRESET_FULL_RECT)
	painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(painter)
	add_child(root)
	# The boss is rebuilt on every respawn, so the reference has to be renewed
	# rather than held. Holding it is exactly the bug that made the guardian's
	# enemies float in 1-1 (docs/status.md 6).
	Events.level_rebuilt.connect(_find_keeper)
	_find_keeper()

func _find_keeper() -> void:
	keeper = null
	for e in get_tree().get_nodes_in_group("keeper"):
		if e is Node2D:
			keeper = e
			return

func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 2.2)
	if keeper == null or not is_instance_valid(keeper):
		return
	var now: int = int(keeper.get("hp"))
	if _last_hp >= 0 and now < _last_hp:
		_flash = 1.0
	_last_hp = now

## Split out so the bar itself stays a CanvasLayer (which cannot draw) and the
## drawing stays one function with the layout in it.
class Painter extends Control:
	var bar: BossBar = null

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if bar == null or bar.keeper == null or not is_instance_valid(bar.keeper):
			return
		var boss = bar.keeper
		var hp: int = int(boss.get("hp"))
		var act: int = int(boss.call("act"))
		var total: int = Balance.KEEPER_HP
		var width := float(total) * PIP_W + float(total - 1) * GAP
		var origin := Vector2(size.x * 0.5 - width * 0.5, 22.0)

		var font := Art.font(Art.FONT_DISPLAY)
		draw_string(font, origin + Vector2(0.0, -6.0), "THE KEEPER",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.86, 0.88, 0.92, 0.85))
		draw_string(font, origin + Vector2(width - 64.0, -6.0), "ACT %d" % act,
			HORIZONTAL_ALIGNMENT_RIGHT, 64.0, 15, Color(1.0, 0.68, 0.30, 0.9))

		for i in range(total):
			var r := Rect2(origin.x + float(i) * (PIP_W + GAP), origin.y, PIP_W, PIP_H)
			# Act boundaries are drawn into the bar, because "two more and it
			# smashes another pillar" is a thing the pair should be able to plan
			# around rather than discover.
			var boundary := (i + 1) % 2 == 0 and i < total - 1
			if i < hp:
				var lit := Color(0.92, 0.36, 0.28)
				if bar._flash > 0.0:
					lit = lit.lerp(Color.WHITE, bar._flash * 0.6)
				DrawUtil.rounded_rect(self, r, 3.0, lit)
			else:
				DrawUtil.rounded_rect(self, r, 3.0, Color(0.16, 0.14, 0.15, 0.85))
			draw_rect(r, Color(0.05, 0.05, 0.07, 0.9), false, 2.0)
			if boundary:
				draw_line(Vector2(r.position.x + r.size.x + GAP * 0.5, r.position.y - 3.0),
					Vector2(r.position.x + r.size.x + GAP * 0.5, r.position.y + r.size.y + 3.0),
					Color(1.0, 0.68, 0.30, 0.55), 2.0)

		_draw_shot_clock(boss, origin, width)

	## The open core's remaining seconds, drawn only while it is open.
	##
	## This is the guardian's cue and the runner's receipt at once: the runner
	## made the opening and has no other way to find out that it worked, because
	## the shot is somebody else's to take.
	func _draw_shot_clock(boss, origin: Vector2, width: float) -> void:
		var left: float = float(boss.call("open_for"))
		if left <= 0.0:
			return
		var span: float = maxf(float(boss.call("stagger_time")), 0.001)
		var frac := clampf(left / span, 0.0, 1.0)
		var track := Rect2(origin.x, origin.y + PIP_H + 7.0, width, 7.0)
		DrawUtil.rounded_rect(self, track, 3.0, Color(0.06, 0.06, 0.08, 0.85))
		DrawUtil.rounded_rect(self,
			Rect2(track.position, Vector2(track.size.x * frac, track.size.y)),
			3.0, Color(1.0, 0.78, 0.30))
		draw_string(Art.font(Art.FONT_UI),
			Vector2(origin.x, track.position.y + 26.0), "CORE OPEN",
			HORIZONTAL_ALIGNMENT_CENTER, width, 13, Color(1.0, 0.80, 0.36, 0.95))
