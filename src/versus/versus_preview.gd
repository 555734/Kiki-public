extends "res://src/ui/placement_preview.gd"
## Co-op's world-space cursor -- the traced platform's ghost, the rifle's
## reticle and lock, and the shot's tracer -- shown only while it means
## something in versus: while a finger is on the field, and for the moment a
## tracer lasts.
##
## Co-op parks the guardian's ghost wherever they last pointed, because there
## the guardian is a player of their own watching the cursor. Here the same
## person is also running, so a ghost left hanging over the field is clutter
## (and a redraw, and a physics query for the drop guide, every frame).

var _drawn := false

func _process(delta: float) -> void:
	_time += delta
	for t in _tracers:
		t["life"] = float(t["life"]) - delta
	_tracers = _tracers.filter(func(t: Dictionary) -> bool: return float(t["life"]) > 0.0)
	var wanted := not _tracers.is_empty() or _aiming()
	if wanted or _drawn:
		queue_redraw()
	_drawn = wanted

func _aiming() -> bool:
	return is_instance_valid(guardian) and guardian.input_hub != null \
		and guardian.input_hub.aiming()

func _draw() -> void:
	if _aiming():
		super._draw()
		return
	for t in _tracers:
		_draw_tracer(t)
