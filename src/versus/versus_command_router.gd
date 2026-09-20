extends Node
## Turns a guardian's button press into a request to the host.
##
## `Guardian` already has this seam: when `command_router` is set, "ability
## presses become requests sent to the host instead of executing here"
## (src/guardian/guardian.gd:20-23). The cooperative client fills it with
## ClientSession; this fills it with the versus client, and the guardian needs
## no versus-specific code at all.
##
## Three methods, because that is what Guardian calls: request_use,
## request_undo, request_mark.

var client: VersusClient = null

## Slots 1 and 2 are the platform and the wall, and both are rectangles the
## host can turn into real ground for both teams. Slots 3 and 4 -- the shot and
## the warp gates -- are not on this wire yet: they are not rectangles, and
## sending them properly means a message per shape rather than a size. Pressing
## them is refused rather than silently ignored, so a guardian is told.
func request_use(slot: int, at: Vector2, _target_id: int) -> void:
	if client == null:
		return
	if slot != 1 and slot != 2:
		Events.ability_refused.emit("not in this mode yet")
		return
	client.request_build(at, slot)

func request_undo() -> void:
	if client != null:
		client.request_undo()

func request_mark(at: Vector2, kind: int) -> void:
	# A ping costs nothing and changes nothing, so it can be shown locally at
	# once. The host relays it to everyone else.
	Events.pinged.emit(at, kind, false)
