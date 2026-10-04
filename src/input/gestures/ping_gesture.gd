class_name PingGesture
extends TouchGesture
## The ping button. A tap means "here", a hold means "wait"; the difference is
## only known when the thumb lifts.

var down_ms: int = 0

func begin(_index: int, _position: Vector2, _size: Vector2, _id: String) -> void:
	down_ms = Time.get_ticks_msec()

func end(_index: int, _position: Vector2, cancelled: bool, _previous: Variant) -> void:
	if cancelled:
		return
	var held := Time.get_ticks_msec() - down_ms
	hub._ping_latched = 2 if held >= InputHub.PING_HOLD_MS else 1
