class_name Guardian
extends Node2D
## Player 2. Owns the shared support gauge and the three tools.
##
## The gauge is the whole balance lever from chapter 9: every refusal the
## guardian meets ("not enough gauge", "you are scoped", "there is already a
## wall") exists to stop the god player from simply rebuilding the level and
## reducing the runner to a puppet.

var gauge: float = Balance.GAUGE_MAX
var active_slot: int = 1
var scope_active: bool = false
var zoom_index: int = Balance.SCOPE_ZOOM_DEFAULT_INDEX

var runner: Runner = null
var input_hub: InputHub = null
## Node the constructs are parented to, so they sort with the rest of the world.
var world_root: Node2D = null

## When set, ability presses become requests sent to the host instead of
## executing here. An online guardian asks; it does not act. Offline this stays
## null and nothing changes. See docs/netcode.md section 3.
var command_router: Node = null

var abilities: Dictionary = {}
var _platforms: Array[Hologram] = []
var _walls: Array[Hologram] = []
var _warps: Array[Hologram] = []
## Both mouths go inert briefly after a trip, or the runner arrives inside the
## far gate and is sent straight back on the next frame.
var _warp_cooldown: float = 0.0
var _last_refusal: String = ""
var _refusal_timer: float = 0.0
var _aim_world: Vector2 = Vector2.ZERO

func _ready() -> void:
	abilities = {
		1: BuildAbility.platform(),
		2: BuildAbility.wall(),
		3: SniperAbility.new(),
		4: WarpAbility.make(),
	}
	Events.gauge_changed.emit(gauge, Balance.GAUGE_MAX)
	Events.ability_selected.emit(active_slot)
	# The runner's one way of giving something back. Host-only: on the client
	# the gauge is a readout of the host's number, and topping it up locally
	# would just be overwritten by the next snapshot -- twice a second of the
	# bar jumping and settling.
	Events.runner_landed_on_hologram.connect(_grade_rescue)
	Events.coin_collected.connect(func(_at: Vector2) -> void:
		if Clock.is_host:
			gauge = minf(Balance.GAUGE_MAX, gauge + Balance.COIN_GAUGE)
			Events.gauge_changed.emit(gauge, Balance.GAUGE_MAX))
	# The bigger version of the same idea, and the one the stage is built
	# around. Host-only for the same reason, and awarded by name so a resend
	# cannot pay twice. See _on_crystal_reached.
	Events.crystal_reached.connect(_on_crystal_reached)

func _process(delta: float) -> void:
	_refusal_timer = maxf(0.0, _refusal_timer - delta)
	(abilities[3] as SniperAbility).tick(delta)
	_service_warp(delta)

	gauge = minf(Balance.GAUGE_MAX, gauge + Balance.GAUGE_REGEN_PER_SEC * delta)
	Events.gauge_changed.emit(gauge, Balance.GAUGE_MAX)

	if input_hub == null:
		return
	if input_hub.aim_is_unset() and runner != null and is_instance_valid(runner):
		# Nowhere is not a place. Before the guardian has pointed at anything the
		# reticle sits on the runner, which is both the most useful default and
		# the only one that is on screen.
		input_hub.aim_at_world(runner.global_position)
	_aim_world = input_hub.aim_world()

	# Choose a tool, then tap where it goes.
	#
	# The button used to build. That made the press itself the commit, so the
	# place had to come from somewhere else -- the reticle, or a rule -- and
	# whichever it was, it was not where the player had just pointed. Choosing
	# and placing are two separate answers to two separate questions, and they
	# are two separate touches now. The choice sticks, so a guardian laying a
	# run of platforms taps the button once and then taps the ground.
	var chosen := input_hub.take_slot_choice()
	if chosen > 0:
		select_slot(chosen)
	input_hub.take_slot_was_dragged()   # consumed; the drag is a place, not a rule

	var at := input_hub.take_place_at()
	if at.x != INF and abilities.has(active_slot):
		if command_router != null:
			command_router.request_use(active_slot, at, target_id_at(active_slot, at))
		else:
			use_active(at)

	# Taking one back, and pointing at things. Both go through the router when
	# online for the same reason every other command does: the world is the
	# host's, and a client that changed it locally would be overwritten.
	if input_hub.take_undo():
		if command_router != null:
			command_router.request_undo()
		else:
			undo_last()
	# Not on the runner's own device: the same latch is theirs there, and it
	# marks where they are rather than where a reticle they do not have is
	# pointing. Main reads it in that case.
	var mark := input_hub.take_ping() if input_hub.solo_role != "runner" else 0
	if mark > 0:
		if command_router != null:
			command_router.request_mark(_aim_world, mark)
		else:
			Events.pinged.emit(_aim_world, mark, false)

	if input_hub.take_scope():
		set_scope(not scope_active)

	var zoom := input_hub.take_zoom()
	if zoom != 0 and scope_active:
		set_zoom_index(zoom_index + zoom)

	# There used to be a separate "commit" here, reading a left click (p2_use)
	# and using whichever tool was current. That is the mode this design is
	# meant to be rid of: a control whose meaning depends on an earlier choice.
	# Each tool's own key and each tool's own button use that tool, and nothing
	# else places anything.

	# The gauge is the host's number when online: it is the constraint the whole
	# design rests on, so a client that could set it would delete the constraint.
	# The client predicts it and eases toward the authoritative value instead.
	if command_router != null:
		gauge = minf(gauge, Balance.GAUGE_MAX)

## Which tool the cursor is showing. No longer a mode the guardian has to be in
## before they can act -- it only decides which ghost is drawn and which tile is
## lit, and it follows whichever button was pressed last.
## The catch, graded.
##
## Host-only, like everything that spends gauge: the client is shown the result
## through the relayed event rather than working it out from a puppet it does
## not simulate.
func _grade_rescue(holo: Node2D) -> void:
	if not Clock.is_host or not is_instance_valid(holo):
		return
	if holo.kind != Hologram.Kind.PLATFORM:
		return
	if runner == null or not is_instance_valid(runner):
		return
	# A runner who walked onto a slab has not been rescued from anything.
	if runner.impact_speed() < Balance.RESCUE_MIN_FALL:
		return
	var since: int = holo.placed_tick if holo.placed_tick >= 0 else holo.birth_tick
	var age := float(Clock.tick - since) * Clock.DT
	var tier := 0
	if age <= float(Balance.RESCUE_TIERS[2]):
		tier = 3
	elif age <= float(Balance.RESCUE_TIERS[1]):
		tier = 2
	elif age <= float(Balance.RESCUE_TIERS[0]):
		tier = 1
	if tier == 0:
		return
	gauge = minf(Balance.GAUGE_MAX, gauge + float(Balance.RESCUE_REFUND[tier]))
	Events.gauge_changed.emit(gauge, Balance.GAUGE_MAX)
	Events.rescue_scored.emit(tier, holo.global_position)



func select_slot(slot: int) -> void:
	if not abilities.has(slot):
		return
	active_slot = slot
	Events.ability_selected.emit(active_slot)

## The optic, now independent of the tools.
##
## It used to be raised by selecting the sniper, which is where chapter 4's
## "scoped means not building" came from: the scope WAS the choice. With a
## button per tool the choice is made per press and paid for in gauge, so the
## scope goes back to being what it looks like -- a magnifier -- and no longer
## refuses anything. That is forced by the one-press rule: a button that answers
## "lower the scope first" has not been pressed once, it has been pressed once
## and ignored.
func set_scope(active: bool) -> void:
	_set_scope(active)

func set_zoom_index(index: int) -> void:
	zoom_index = clampi(index, 0, Balance.SCOPE_ZOOM_STEPS.size() - 1)
	if scope_active:
		Events.scope_state_changed.emit(true, current_zoom())

func current_zoom() -> float:
	return Balance.SCOPE_ZOOM_STEPS[zoom_index]

func use_active(world_pos: Vector2) -> void:
	var ability: GuardianAbility = abilities[active_slot]
	var reason := ability.check(self, world_pos)
	if reason != "":
		_last_refusal = reason
		_refusal_timer = 0.8
		Events.ability_refused.emit(active_slot, reason)
		return
	gauge = maxf(0.0, gauge - ability.cost)
	ability.execute(self, world_pos)
	Events.gauge_changed.emit(gauge, Balance.GAUGE_MAX)
	Events.ability_used.emit(active_slot, world_pos)

## What the guardian would get if they committed right now.
##
## The tool whose button is under a thumb wins over the last one used. Holding a
## button is how you aim with it, so the ghost has to be the thing you are
## holding -- otherwise a press-drag-release shows you one tool and places
## another, which is the sort of thing that makes players stop trusting a
## control.
## The ghost: the chosen tool, at the reticle, always.
##
## A tool button being HELD wins over the chosen one, so dragging the wall out
## of its button shows a wall even while the platform is still selected. Let go
## and the choice has changed anyway.
func current_preview() -> Dictionary:
	if input_hub == null:
		return {}
	var slot: int = input_hub.held_slot()
	if slot < 0:
		slot = active_slot
	if not abilities.has(slot):
		return {}
	return preview_of(slot, true)

## The ghost for one tool, resolved the same way its commit will be.
func preview_of(slot: int, dragged: bool) -> Dictionary:
	if not abilities.has(slot):
		return {}
	var ability: GuardianAbility = abilities[slot]
	return ability.preview(self, target_for(slot, dragged))

## Where this tool would land if it were committed right now.
##
## The reticle. Always the reticle, for every tool, whether the button was
## tapped or dragged out of.
##
## There used to be an "auto placement" here: a tap resolved through a set of
## rules -- a platform under a falling runner, a wall between them and the
## nearest threat, a shot at whatever was closest to them -- and only a drag
## used the point the guardian had chosen. The reasoning was that the decision
## worth making is WHICH TOOL, not where. That reasoning was wrong, and it was
## wrong in the way that matters most: it took a place the player had already
## pointed at and quietly replaced it. "I press the wall button and the wall
## appears somewhere completely different" is not a bug report about a rule
## being slightly off. It is the control being untrustworthy.
##
## So there is one rule now, and it is the one a player would guess: tap where
## you want it, press the tool, it goes there. Dragging out of the button still
## works and is the same thing by a different route. The ghost is drawn from
## this function too, so what you see is what you get -- and `dragged` survives
## only because the drag gesture lifts the target clear of the thumb.
func target_for(_slot: int, _dragged: bool) -> Vector2:
	return _aim_world

## Which enemy this device believes the shot is for, by the name both devices
## know it by, or -1. Only the rifle picks a target; everything else is placed
## at a point and means it.
func target_id_at(slot: int, at: Vector2) -> int:
	if slot != 3 or not abilities.has(slot):
		return -1
	var ability: GuardianAbility = abilities[slot]
	if not ability.has_method("target_at"):
		return -1
	var target = ability.target_at(self, at)
	if target == null or not is_instance_valid(target):
		return -1
	var id = target.get("net_id")
	return int(id) if id != null else -1

func aim_world() -> Vector2:
	return _aim_world

## Tracer start point: off the top of the visible area, so the shot reads as
## coming from above rather than from a body on the field.
func tracer_origin(target: Vector2) -> Vector2:
	return target + Vector2(-160.0, -520.0)

func holograms_of(kind: Hologram.Kind) -> Array:
	var list: Array = _list_for(kind)
	# Drop anything that expired on its own before answering. `is_queued_for_
	# deletion` matters as much as `is_instance_valid`: a node freed this frame
	# is still "valid" until the frame ends, so without it a construct that was
	# just recycled is counted against the cap for one more frame -- which for
	# the warp pair meant briefly seeing three gates and pairing the wrong two.
	var alive: Array = []
	for h in list:
		if is_instance_valid(h) and not h.is_queued_for_deletion():
			alive.append(h)
	list.assign(alive)
	return alive

func _list_for(kind: Hologram.Kind) -> Array:
	match kind:
		Hologram.Kind.PLATFORM: return _platforms
		Hologram.Kind.WALL: return _walls
		_: return _warps

## The one the guardian just put down, so it can be taken back.
var _last_placed: Hologram = null

## Take back the last platform or wall. No refund.
##
## This is not an undo for the cost -- the gauge is gone and stays gone, or it
## would be a free retry and placement would stop being a decision. It is for
## the wall that went across the doorway the runner was about to use, which
## before this had to be waited out while the runner stood there.
##
## Warp gates are excluded: they come in pairs and revoking half a pair leaves
## a doorway to nowhere, which is worse than the mistake.
func undo_last() -> bool:
	if _last_placed == null or not is_instance_valid(_last_placed) \
			or _last_placed.is_queued_for_deletion():
		_last_placed = null
		return false
	var id: int = _last_placed.net_id
	var kind: int = int(_last_placed.kind)
	_list_for(_last_placed.kind).erase(_last_placed)
	_last_placed.queue_free()
	_last_placed = null
	Events.hologram_revoked.emit(id)
	Events.hologram_expired.emit(kind)
	return true

## A crystal the runner has reached.
##
## Host only, and the only place the gauge goes up by a crystal. The guardian's
## device is told the outcome rather than working it out: its runner is a puppet
## a few ticks behind, so the two would disagree at the edge of the radius --
## and then one screen has spent a crystal the other still has.
func _on_crystal_reached(crystal: Node2D) -> void:
	if not Clock.is_host or crystal == null or not is_instance_valid(crystal):
		return
	# take_crystal is the whole defence against paying twice: it answers true
	# once and false ever after, so a resend, a second frame of contact and a
	# reconnect all land on the same "already had it".
	if not GameState.take_crystal(int(crystal.get("net_id"))):
		return
	crystal.call("collect")
	gauge = minf(Balance.GAUGE_MAX, gauge + float(crystal.get("amount")))
	Events.gauge_changed.emit(gauge, Balance.GAUGE_MAX)
	Events.crystal_taken.emit(int(crystal.get("net_id")), crystal.global_position,
		float(crystal.get("amount")))

func spawn_hologram(holo: Hologram) -> void:
	# The warp pair rule lives here rather than in WarpAbility so that a gate
	# arriving from the host over the network obeys it too. Both devices apply
	# the same rule to the same sequence of gates and stay in step without a
	# packet having to say "and drop the old pair" -- the same reasoning as the
	# tick-derived gimmicks in docs/netcode.md section 4.
	if holo.kind == Hologram.Kind.WARP:
		var open: Array = holograms_of(Hologram.Kind.WARP)
		if open.size() >= 2:
			# A third press starts a NEW pair. Recycling the oldest the way the
			# platform does would leave the guardian pointing yesterday's exit at
			# today's entrance, which is not something anyone could aim.
			for old in open:
				if is_instance_valid(old):
					old.expire()
			_warps.clear()
	var parent: Node = world_root if world_root != null else get_parent()
	parent.add_child(holo)
	if holo.kind != Hologram.Kind.WARP:
		_last_placed = holo
	# The trigger needs to know who it is throwing. Set here rather than inside
	# the construct so it happens on the guardian's device too, where the
	# construct arrives from the host and there is no placement to hook into.
	if holo.trigger != null:
		holo.trigger.runner = runner
	_list_for(holo.kind).append(holo)
	if holo.kind == Hologram.Kind.WARP:
		_relink_warps()

## A gate is only a way through once it has a partner, and the gates themselves
## draw differently depending on it, so the flag is refreshed wherever the pair
## can change.
func _relink_warps() -> void:
	var gates: Array = holograms_of(Hologram.Kind.WARP)
	for g in gates:
		g.linked = gates.size() >= 2

## The trip itself. Host-only: the runner's position is the host's to set, and a
## client that moved its own puppet would simply be overwritten by the next
## snapshot -- twice a second of the runner snapping back and forth.
func _service_warp(delta: float) -> void:
	_warp_cooldown = maxf(0.0, _warp_cooldown - delta)
	var gates: Array = holograms_of(Hologram.Kind.WARP)
	_relink_warps()
	if not Clock.is_host or _warp_cooldown > 0.0:
		return
	if gates.size() < 2 or runner == null or not is_instance_valid(runner):
		return
	var here: Vector2 = runner.global_position
	var mouth := -1
	for i in 2:
		if _inside_gate(gates[i], here):
			mouth = i
			break
	if mouth < 0:
		return
	var exit_gate: Hologram = gates[1 - mouth]
	var from := here
	# Velocity is kept. A runner who sprints into a gate should come out of the
	# other one sprinting: the gate moves them, it does not stop them, and
	# landing a jump through a warp is the whole trick.
	runner.global_position = exit_gate.global_position
	_warp_cooldown = Balance.WARP_COOLDOWN
	Events.runner_warped.emit(from, exit_gate.global_position)

func _inside_gate(gate: Hologram, point: Vector2) -> bool:
	if not is_instance_valid(gate):
		return false
	return Rect2(gate.global_position - gate.size * 0.5, gate.size).has_point(point)

func ammo() -> int:
	return SniperAbility.ammo_for(gauge)

func refusal() -> String:
	return _last_refusal if _refusal_timer > 0.0 else ""

func _set_scope(active: bool) -> void:
	if scope_active == active:
		return
	scope_active = active
	Events.scope_state_changed.emit(scope_active, current_zoom())

## Used when the runner dies: constructs should not survive a checkpoint reset,
## or the guardian could pre-build the retry.
func clear_constructs() -> void:
	for list in [_platforms, _walls, _warps]:
		for h in list:
			if is_instance_valid(h):
				h.queue_free()
	_platforms.clear()
	_walls.clear()
	_warps.clear()
	_warp_cooldown = 0.0
