extends FinaleMachine
## VERTICAL COLLAPSE. The last floor of the ruin hall is a lid over a 1,500px
## shaft. Standing on it cracks it; 0.45s later the tiles drop one after
## another, left to right, and the runner falls with them into the volcano.
## state 1 = cracking began at placed_tick.

const CRACK := 0.45
const STAGGER := 0.08
var _tiles: Array[AnimatableBody2D] = []

func _build() -> void:
	z_index = 3
	var n := int(data.get("tiles", 5))
	var w := float(data.get("tile_w", 80.0))
	var thick := float(data.get("thick", 40.0))
	for i in n:
		var b := make_body(Vector2(w, thick))
		b.position = Vector2(w * (float(i) + 0.5), thick * 0.5)
		_tiles.append(b)

func tile_gone(i: int, tick: int) -> bool:
	return state == 1 and since(tick) >= CRACK + STAGGER * float(i)

func _pose(tick: int) -> void:
	for i in _tiles.size():
		set_solid(_tiles[i], not tile_gone(i, tick))

func _on_state() -> void:
	sound("gate", -8.0, 1.2)
	FinaleFx.kick(6.0)

func _host_step(_delta: float) -> void:
	if state == 1:
		return
	for b in _tiles:
		if runner_on(b):
			set_state(1)
			return

func _draw() -> void:
	var w := float(data.get("tile_w", 80.0))
	var thick := float(data.get("thick", 40.0))
	var age := since() if state == 1 else 0.0
	for i in _tiles.size():
		var r := Rect2(w * float(i), 0, w, thick)
		var fall := 0.0
		var spin := 0.0
		if tile_gone(i, Clock.tick):
			var t := age - CRACK - STAGGER * float(i)
			if t > 2.0:
				continue
			fall = 0.5 * 1900.0 * t * t
			spin = t * (1.5 if i % 2 == 0 else -1.8)
		elif state == 1:
			r.position.x += sin(age * 70.0 + i) * 2.0
		draw_set_transform(r.get_center() + Vector2(0, fall), spin, Vector2.ONE)
		FinaleArt.slab_on(self, Rect2(-r.size * 0.5, r.size), "sand")
		draw_set_transform(Vector2.ZERO)
		if state == 1 and fall == 0.0:
			draw_line(r.position + Vector2(12, 6), r.position + Vector2(40, 30), Color("4a2e1e"), 3.0)
			draw_line(r.position + Vector2(40, 30), r.position + Vector2(66, 12), Color("4a2e1e"), 3.0)
	# Sand pouring through as it opens.
	if state == 1 and age > CRACK:
		for k in 14:
			var x := fposmod(float(k) * 41.0, w * _tiles.size())
			var y := fposmod(age * 600.0 + k * 53.0, 900.0)
			draw_circle(Vector2(x, thick + y), 5.0, Color("e2bc72", 0.8))
