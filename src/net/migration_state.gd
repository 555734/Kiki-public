class_name MigrationState
extends RefCounted
## Versioned authoritative checkpoint used only for host migration. A frame is
## restored only when every chunk arrived and its digest matches.

const VERSION := 1
const MAX_AGE_MS := 500
const SEND_EVERY_TICKS := 15 # 250 ms at 60 Hz; leaves transit budget.
const CHUNK_BYTES := 1000

static func capture(main: Node2D) -> PackedByteArray:
	var state := {
		"version": VERSION,
		"captured_ms": Time.get_ticks_msec(),
		"tick": Clock.tick,
		"stage": Stage.current(),
		"game": {
			"checkpoint_index": GameState.checkpoint_index,
			"checkpoint_position": GameState.checkpoint_position,
			"stage_start_position": GameState.stage_start_position,
			"crystals_taken": GameState.crystals_taken,
			"boss_hp": GameState.boss_hp,
			"deaths": GameState.deaths,
			"rescues": GameState.rescues,
			"rescue_tiers": GameState.rescue_tiers,
			"enemies_sniped": GameState.enemies_sniped,
			"enemies_stomped": GameState.enemies_stomped,
			"shots_blocked": GameState.shots_blocked,
			"elapsed": GameState.elapsed,
		},
		"runner": _node_state(main.runner, [
			"global_position", "velocity", "state", "hp", "facing",
			"_invulnerable", "_hurt_timer", "_dash_timer"]),
		"guardian": _node_state(main.guardian, ["gauge", "active_slot"]),
		"groups": {},
	}
	for group in ["enemy", "hologram", "projectile", "switch", "gate",
			"barricade", "crystal", "coin"]:
		var rows: Array = []
		for node in main.get_tree().get_nodes_in_group(group):
			if node is Node:
				rows.append(_node_state(node, [
					"global_position", "velocity", "net_id", "hp", "state", "facing",
					"_timer", "_cooldown", "_open_until", "_phase", "active",
					"reached", "birth_tick", "death_tick", "placed_tick",
					"wounded_this_stagger", "_shock_spent", "armed", "kind"] ))
		state["groups"][group] = rows
	return var_to_bytes(state)

static func decode(payload: PackedByteArray) -> Dictionary:
	var value = bytes_to_var(payload)
	if typeof(value) != TYPE_DICTIONARY or int(value.get("version", -1)) != VERSION:
		return {}
	return value

static func is_fresh(state: Dictionary, now_ms: int = Time.get_ticks_msec()) -> bool:
	return not state.is_empty() and now_ms - int(state.get("captured_ms", 0)) <= MAX_AGE_MS

static func apply(main: Node2D, state: Dictionary) -> bool:
	if state.is_empty() or int(state.get("stage", -1)) != Stage.current():
		return false
	Clock.reset(int(state.get("tick", 0)))
	var game: Dictionary = state.get("game", {})
	for key in game:
		GameState.set(key, game[key])
	_apply_node_state(main.runner, state.get("runner", {}))
	_apply_node_state(main.guardian, state.get("guardian", {}))
	var groups: Dictionary = state.get("groups", {})
	for group in groups:
		_apply_group(main, String(group), groups[group])
	return true

static func chunks(payload: PackedByteArray, generation: int, tick: int) -> Array[PackedByteArray]:
	var out: Array[PackedByteArray] = []
	var total := ceili(float(payload.size()) / float(CHUNK_BYTES))
	var frame_digest := digest(payload)
	for index in total:
		var b := StreamPeerBuffer.new()
		b.big_endian = false
		b.put_u8(Protocol.Msg.MIGRATION_CHUNK)
		b.put_u32(generation)
		b.put_u32(tick)
		b.put_u16(index)
		b.put_u16(total)
		b.put_u16(payload.size())
		b.put_data(frame_digest)
		b.put_data(payload.slice(index * CHUNK_BYTES,
			mini(payload.size(), (index + 1) * CHUNK_BYTES)))
		out.append(b.data_array)
	return out

static func digest(payload: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return PackedByteArray()
	if context.update(payload) != OK:
		return PackedByteArray()
	return context.finish().slice(0, 8)

static func _node_state(node: Object, fields: Array) -> Dictionary:
	if node == null or not is_instance_valid(node):
		return {}
	var out := {"name": String((node as Node).name) if node is Node else ""}
	var properties := {}
	for info in node.get_property_list():
		properties[String(info["name"])] = true
	for key in fields:
		if properties.has(key):
			out[key] = node.get(key)
	return out

static func _apply_node_state(node: Object, values: Dictionary) -> void:
	if node == null or not is_instance_valid(node):
		return
	var properties := {}
	for info in node.get_property_list():
		properties[String(info["name"])] = true
	for key in values:
		if key != "name" and properties.has(key):
			node.set(key, values[key])

static func _apply_group(main: Node2D, group: String, rows: Array) -> void:
	var nodes := main.get_tree().get_nodes_in_group(group)
	var by_key := {}
	for node in nodes:
		by_key[_node_key(node)] = node
	var live := {}
	for row in rows:
		var key := _row_key(row)
		live[key] = true
		if by_key.has(key):
			_apply_node_state(by_key[key], row)
	# Nodes absent from the authoritative frame are dead/collected. Spawned
	# nodes that do not exist locally are recreated by the normal resync event
	# path immediately after authority is ready.
	for key in by_key:
		if not live.has(key) and is_instance_valid(by_key[key]):
			by_key[key].queue_free()

static func _node_key(node: Object) -> String:
	var id = node.get("net_id")
	return "id:%s" % id if id != null and int(id) >= 0 else "name:%s" % (node as Node).name

static func _row_key(row: Dictionary) -> String:
	return "id:%s" % row["net_id"] if row.has("net_id") and int(row["net_id"]) >= 0 \
		else "name:%s" % String(row.get("name", ""))
