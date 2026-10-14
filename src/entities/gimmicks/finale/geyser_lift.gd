extends FinaleMachine
## BETWEEN THE GEYSERS. A basalt slab capping a vent. Every cycle the vent
## rumbles (0.9s of steam and shaking), erupts, and throws the slab `rise` px
## straight up, where it holds for 1.6s before sinking back. Stand on it to
## ride the eruption to the next ledge; three stacked lifts climb 1,000px.

const WARN := 0.9
const UP := 0.4
const HOLD := 1.6
const DOWN := 1.0
var _slab: AnimatableBody2D
var _was_up := false

func _build() -> void:
	z_index = 4
	_slab = make_body(Vector2(float(data.get("width", 120.0)), 30.0))

func lift_at(tick: int) -> float:
	var beat := fposmod(Clock.seconds_at(tick, float(data.get("phase", 0.0))), float(data.get("period", 4.0)))
	var rise := float(data.get("rise", 300.0))
	if beat < WARN:
		return 0.0
	beat -= WARN
	if beat < UP:
		var k := beat / UP
		return rise * (1.0 - (1.0 - k) * (1.0 - k))
	beat -= UP
	if beat < HOLD:
		return rise
	beat -= HOLD
	if beat < DOWN:
		return rise * (0.5 + 0.5 * cos(PI * beat / DOWN))
	return 0.0

func warning_at(tick: int) -> bool:
	var beat := fposmod(Clock.seconds_at(tick, float(data.get("phase", 0.0))), float(data.get("period", 4.0)))
	return beat < WARN and beat > 0.15

func _pose(tick: int) -> void:
	var lift := lift_at(tick)
	var shake := 0.0
	if warning_at(tick):
		shake = sin(Clock.seconds_at(tick) * 60.0) * 2.0
	_slab.position = Vector2(shake, 15.0 - lift)
	var up := lift > 1.0
	if up and not _was_up:
		sound("spring", -7.0)
	_was_up = up

func _draw() -> void:
	var w := float(data.get("width", 120.0))
	var lift := lift_at(Clock.tick)
	var t := seconds()
	# Vent.
	draw_rect(Rect2(-w * 0.35, 0, w * 0.7, 26), Color("2a1418"))
	draw_rect(Rect2(-w * 0.28, 0, w * 0.56, 8), Color(1, 0.5 + 0.3 * sin(t * 8.0), 0.1))
	if lift > 1.0:
		var col := FinaleArt.tex("lava_column")
		if col != null:
			draw_texture_rect(col, Rect2(-w * 0.32, -lift + 20, w * 0.64, lift), false)
		for k in 6:
			var a := t * 7.0 + k
			draw_circle(Vector2(sin(a) * w * 0.45, -lift + 24 + cos(a) * 8), 8.0, Color(1, 0.7, 0.2, 0.9))
	elif warning_at(Clock.tick):
		for k in 5:
			var life := fposmod(t * 1.6 + k * 0.2, 1.0)
			draw_circle(Vector2((k - 2) * 16.0, -life * 70.0), 10.0 + life * 14.0, Color(1, 0.9, 0.8, 0.5 * (1.0 - life)))
	FinaleArt.centred(self, "lava_platform", _slab.position + Vector2(0, 6), w + 26.0)
