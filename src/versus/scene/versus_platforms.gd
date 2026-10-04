class_name VersusPlatforms
extends RefCounted
## Everything the guardians build, on this machine.
##
## Two things, and they are kept together because they are the same platforms
## seen two ways: the Holograms each player's Guardian places (sent to everyone,
## with a copy one lap either side because the field is a loop), and the rects
## the host's ledger counts as ground, rebuilt here as one static body.

var arena = null

## Every platform on this machine, by "seat:id": the Hologram plus its copies
## one lap either side. Own platforms are the Guardian's; the others arrive
## from the host.
var holos: Dictionary = {}
var _next_holo_id: int = 1

## The host's built ground, and the seat that built each piece.
var built: Array[Rect2] = []
var build_owner: Array[int] = []
var _built_revision: int = -1
var _built_body: StaticBody2D = null

func _init(owner_arena) -> void:
	arena = owner_arena

# ---------------------------------------------------------------- holograms

func sync_holograms() -> void:
	var seat: int = arena._seat
	var guardian: Guardian = arena.guardian
	# Mine: anything new the Guardian made goes out; anything gone is ended.
	if guardian != null and seat >= 0:
		var mine: Dictionary = {}
		for holo in guardian.holograms_of(Hologram.Kind.PLATFORM):
			if not is_instance_valid(holo) or holo.is_queued_for_deletion():
				continue
			if not holo.has_meta("vs_id"):
				holo.set_meta("vs_id", _next_holo_id)
				_next_holo_id = (_next_holo_id % 0xFFFF) + 1
				var payload := VersusProtocol.holo(seat, int(holo.get_meta("vs_id")),
					int(holo.kind), Vector2(VersusStageData.wrap_x(holo.global_position.x),
						holo.global_position.y), holo.path)
				_send_holo(payload)
				holos["%d:%d" % [seat, int(holo.get_meta("vs_id"))]] = {
					"main": holo, "copies": _lap_copies(holo.kind, holo.global_position, holo.path)}
			mine["%d:%d" % [seat, int(holo.get_meta("vs_id"))]] = true
		for key in holos.keys():
			if String(key).begins_with("%d:" % seat) and not mine.has(key):
				var id := int(String(key).split(":")[1])
				drop_holo(key)
				_send_holo(VersusProtocol.unholo(seat, id))
	# Theirs.
	var inbox: Array[PackedByteArray] = []
	if arena.host != null:
		inbox = arena.host.holo_inbox
	elif arena.client != null:
		inbox = arena.client.holo_inbox
	for payload in inbox:
		match VersusProtocol.kind_of(payload):
			VersusProtocol.Msg.HOLO:
				var h := VersusProtocol.read_holo(payload)
				var key := "%d:%d" % [int(h["seat"]), int(h["holo_id"])]
				drop_holo(key)
				var main := _remote_holo(int(h["kind"]), h["at"], h["path"])
				holos[key] = {"main": main,
					"copies": _lap_copies(int(h["kind"]), h["at"], h["path"])}
			VersusProtocol.Msg.UNHOLO:
				var u := VersusProtocol.read_unholo(payload)
				drop_holo("%d:%d" % [int(u["seat"]), int(u["holo_id"])])
	inbox.clear()
	# Copies follow their original out (expiry is each one's own 6 s).
	for key in holos.keys():
		var entry: Dictionary = holos[key]
		if not is_instance_valid(entry["main"]) or entry["main"].is_queued_for_deletion():
			drop_holo(key, false)

func _send_holo(payload: PackedByteArray) -> void:
	if arena.host != null:
		arena.host.send_holo(payload)
	elif arena.client != null:
		arena.client.send_holo(payload)

## Somebody else's platform: the same Hologram, built the same way, but not
## the local Guardian's (it does not count against this player's two) and
## its launch trigger throws nobody here.
func _remote_holo(kind: int, at: Vector2, path: PackedVector2Array) -> Hologram:
	var holo := Hologram.create(kind, at, path)
	arena.add_child(holo)
	if holo.trigger != null:
		holo.trigger.runner = null
	return holo

func _lap_copies(kind: int, at: Vector2, path: PackedVector2Array) -> Array:
	var out: Array = []
	for lap in [-1, 1]:
		var copy_at := at + Vector2(VersusStageData.WIDTH * float(lap), 0.0)
		# Only near the join is a copy ever reachable or on screen.
		if copy_at.x < VersusStageData.LEFT - VersusStageData.LAP_MARGIN - 300.0 \
				or copy_at.x > VersusStageData.RIGHT + VersusStageData.LAP_MARGIN + 300.0:
			continue
		out.append(_remote_holo(kind, copy_at, path))
	return out

func drop_holo(key: String, include_main: bool = true) -> void:
	if not holos.has(key):
		return
	var entry: Dictionary = holos[key]
	var nodes: Array = entry["copies"].duplicate()
	if include_main and not String(key).begins_with("%d:" % arena._seat):
		nodes.append(entry["main"])
	for n in nodes:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			n.expire()
	holos.erase(key)

## Every platform goes with the old match: this player's own, and the copies
## of everyone else's (each machine clears its own the same way).
func clear_holograms() -> void:
	if arena.guardian != null:
		arena.guardian.clear_constructs()
	for key in holos.keys():
		drop_holo(key)

# ------------------------------------------------------------- built ground

## The ledger's platforms from the host's own match.
func sync_builds(from: Array, revision: int) -> void:
	if revision == _built_revision:
		return
	built.clear()
	build_owner.clear()
	for g in from:
		built.append(g["rect"])
		build_owner.append(int(g["seat"]))
	_built_revision = revision
	refresh_ground()

## The same, from a guest's snapshot.
func sync_builds_from_snapshot(from: Array, revision: int) -> void:
	if revision == _built_revision:
		return
	built.clear()
	build_owner.clear()
	for g in from:
		built.append(Rect2(g["position"], g["size"]))
		build_owner.append(int(g["seat"]))
	_built_revision = revision
	refresh_ground()

## A new match: nothing is built.
func clear_builds() -> void:
	built.clear()
	build_owner.clear()
	_built_revision = -1
	refresh_ground()

## A guest's rematch: whatever the next snapshot says is new.
func forget_revision() -> void:
	_built_revision = -1

## The guardians' constructs are ordinary ground for both teams. Rebuilt as one
## body whenever the list changes rather than added one at a time, so the shape
## of the world is always exactly the list.
func refresh_ground() -> void:
	if _built_body == null:
		_built_body = StaticBody2D.new()
		_built_body.name = "Built"
		_built_body.collision_layer = 1
		_built_body.collision_mask = 0
		arena.add_child(_built_body)
	for child in _built_body.get_children():
		child.queue_free()
	# One lap either side as well, so a platform on the join is solid from
	# whichever side it is reached.
	for rect in _built_laps():
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.position + rect.size * 0.5
		_built_body.add_child(shape)

func _built_laps() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for lap in VersusStageData.LAPS:
		for r in built:
			out.append(Rect2(r.position + Vector2(VersusStageData.WIDTH * float(lap), 0.0), r.size))
	return out
