extends FinaleMachine
## The canyon's bed, far below the bridges: dunes of drifting sand. Only
## paint -- the invisible hazard under it ends a fall.

func _build() -> void:
	z_index = 1

func _physics_process(_delta: float) -> void:
	pass

func _draw() -> void:
	var w := float(data.get("width", 4000.0))
	var dunes := PackedVector2Array()
	for i in 41:
		var x := w * float(i) / 40.0
		dunes.append(Vector2(x, sin(float(i) * 0.9) * 26.0 + sin(float(i) * 0.37) * 18.0))
	dunes.append(Vector2(w, 500))
	dunes.append(Vector2(0, 500))
	draw_colored_polygon(dunes, Color("c98a4b"))
	draw_polyline(dunes.slice(0, 41), Color("f0c27e"), 6.0, true)
	draw_rect(Rect2(0, 120, w, 380), Color(0.45, 0.25, 0.15, 0.4))
