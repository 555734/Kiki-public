class_name ShootableSwitch
extends Area2D
## A target only the guardian can reach. Chapter 4 lists remote switches as a
## sniper use precisely so the gun is not just a way to delete enemies -- here
## it buys the runner a door, on a timer that forces the pair to move together.

const LAYER_SHOOTABLE := 64

@export var switch_id: String = "gate_a"
@export var hold_time: float = 6.0
## Which mark is painted on this one, or 0 for a plain switch.
##
## Only the RUNNER is shown it. The guardian can see the switch perfectly well
## -- they have to, they are the one who shoots it -- but not which of them it
## is. See Sigil, and the other half of this in gate.gd.
@export var sigil: int = 0

var active: bool = false
## Shot while another switch on the same gate was wrong, so nobody may be shot
## for a moment. Costs the pair time and nothing else.
var _locked: float = 0.0
var _remaining: float = 0.0
var _pulse: float = 0.0

func _ready() -> void:
	add_to_group("shootable")
	# Named so the host can find the open ones and replay them to a client that
	# reconnected after the gate was already shot open.
	add_to_group("switch")
	collision_layer = LAYER_SHOOTABLE
	collision_mask = 0
	z_index = 5
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	add_child(shape)

func _process(delta: float) -> void:
	_pulse += delta
	_locked = maxf(0.0, _locked - delta)
	if active:
		_remaining -= delta
		if _remaining <= 0.0:
			active = false
			Events.switch_activated.emit(switch_id + ":off")
	queue_redraw()

## How long every switch on a gate goes quiet after a wrong one is shot.
const WRONG_LOCKOUT: float = 4.0

func take_damage(_amount: int, _by: String = "snipe") -> void:
	if _locked > 0.0:
		return
	# A plain switch (sigil 0) is the old behaviour: shooting it opens the gate.
	# A marked one has to be the RIGHT one, and being wrong is answered with
	# four seconds rather than with a death -- the pair mis-heard each other,
	# which is the game working, not the player being punished.
	if sigil > 0 and not Sigil.opens(switch_id, sigil):
		for other in get_tree().get_nodes_in_group("switch"):
			if other is ShootableSwitch and other.switch_id == switch_id:
				(other as ShootableSwitch)._locked = WRONG_LOCKOUT
		# Not a new kind of event: a shot that connected and did nothing is
		# exactly what shot_blocked already means, it already reaches the
		# guardian's screen, and it already sounds like a refusal.
		Events.shot_blocked.emit(global_position)
		return
	active = true
	_remaining = hold_time
	Events.switch_activated.emit(switch_id)

func locked() -> bool:
	return _locked > 0.0

func reset_state() -> void:
	active = false
	_remaining = 0.0
	_locked = 0.0

func _draw() -> void:
	_draw_body()
	# The mark, for the one player who is allowed to read it. Drawn last so it
	# sits on top of the plate whichever art path ran above.
	if sigil > 0 and Sigil.shown_to(Veil.RUNNER):
		Sigil.draw_mark(self, sigil, Vector2(0.0, -30.0), 11.0,
			Color("1b2029") if active else Color("cfd6e2"))

func _draw_body() -> void:
	var lit := Color("8b93a1") if _locked > 0.0 \
		else (Color("ffd24a") if active else Color("8b93a1"))
	var glow := 0.5 + 0.5 * sin(_pulse * (7.0 if active else 2.2))
	if Balance.USE_TEXTURES and Art.tex("switch_off") != null:
		var pulse := 1.0 + glow * (0.10 if active else 0.03)
		Art.draw_sprite(self, "switch_on" if active else "switch_off",
			Vector2(0.0, 26.0 * pulse), 52.0 * pulse)
		if active:
			var frac := clampf(_remaining / maxf(hold_time, 0.001), 0.0, 1.0)
			draw_arc(Vector2.ZERO, 30.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 40,
				Color("ffd24a"), 3.5, true)
		return
	# Mounting plate
	DrawUtil.rounded_rect(self, Rect2(-16, -16, 32, 32), 8.0, Color("39414d"))
	draw_circle(Vector2.ZERO, 13.0 + glow * 2.0, Color(lit.r, lit.g, lit.b, 0.28))
	draw_circle(Vector2.ZERO, 9.0, lit)
	draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.85))
	# Crosshair ticks, so it reads as "shoot me"
	for i in range(4):
		var a := float(i) * PI * 0.5 + PI * 0.25
		var d := Vector2(cos(a), sin(a))
		draw_line(d * 15.0, d * 20.0, Color(lit.r, lit.g, lit.b, 0.9), 2.4)
	if active:
		var frac := clampf(_remaining / maxf(hold_time, 0.001), 0.0, 1.0)
		draw_arc(Vector2.ZERO, 22.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, Color("ffd24a"), 3.0, true)
