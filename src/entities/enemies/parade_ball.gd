class_name ParadeBall
extends Node2D
## A telegraphed low prop ball pushes the crowd; guardian walls catch it.
var direction := 1
var runner: Runner
var birth_tick := -1
var origin := Vector2.ZERO
func _ready() -> void:
	if birth_tick < 0: birth_tick = Clock.tick
	origin = global_position
	z_index = 5
func _physics_process(_delta: float) -> void:
	global_position = origin + Vector2(direction * 330 * (Clock.tick - birth_tick) / 60.0,0)
	if Clock.tick - birth_tick > 140:
		queue_free()
		return
	for wall in get_tree().get_nodes_in_group("hologram"):
		if wall is Hologram and wall.kind == Hologram.Kind.WALL and wall.global_position.distance_to(global_position) < 70:
			if Clock.is_host: Events.shot_blocked.emit(global_position)
			queue_free()
			return
	if is_instance_valid(runner) and runner.global_position.distance_to(global_position) < 38:
		if Clock.is_host: runner.launch(Vector2(direction * 350, -200))
		queue_free()
		return
	if not Clock.is_host:
		queue_redraw()
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and not e is ParadeActor and e.global_position.distance_to(global_position) < 48:
			if e.has_method("parade_impulse"): e.parade_impulse(Vector2(direction * 450,-350))
	if Clock.tick - birth_tick > 140: queue_free()
	queue_redraw()
func _draw() -> void:
	draw_circle(Vector2.ZERO, 17, Color("df6554"))
	draw_arc(Vector2.ZERO, 13, 0, TAU, 20, Color("edc779"), 3)
	draw_line(Vector2(-8, -8), Vector2(8, 8), Color("39c9ce"), 5)
