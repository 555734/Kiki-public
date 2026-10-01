extends Node
## Turns a player's rifle shot into a request to whoever decides the match.
##
## `Guardian` already has this seam: with `command_router` set, a tap on the
## world becomes a request instead of executing locally (guardian.gd). Versus
## gives each player the co-op rifle and nothing else, so the only thing this
## carries is slot 3, the shot; the arena sends it to the host (or, in the
## one-device test, judges it itself).

var arena = null

func request_use(slot: int, at: Vector2, _target_id: int) -> void:
	if arena != null and slot == 3:
		arena.request_shot(at)

func request_undo() -> void:
	pass

func request_mark(_at: Vector2, _kind: int) -> void:
	pass
