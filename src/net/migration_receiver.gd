class_name MigrationReceiver
extends RefCounted
## Reassembles the host's migration state from MIGRATION_CHUNK messages, so
## this device can take the world over if the host goes away. Keeps only the
## newest complete, digest-checked state, and only while it is fresh.

var _parts: Dictionary = {}
var _latest: Dictionary = {}
var _received_ms: int = -1

func absorb_chunk(b: StreamPeerBuffer) -> void:
	var generation := int(b.get_u32())
	var tick := int(b.get_u32())
	var index := int(b.get_u16())
	var total := int(b.get_u16())
	var payload_size := int(b.get_u16())
	var digest_result := b.get_data(8)
	if digest_result[0] != OK or total <= 0 or total > 64 or index >= total:
		return
	var data_result := b.get_data(b.get_available_bytes())
	if data_result[0] != OK:
		return
	if not _parts.has(generation):
		_parts = {generation: {
			"tick": tick, "total": total, "size": payload_size,
			"digest": digest_result[1], "parts": {},
		}}
	var frame: Dictionary = _parts[generation]
	if frame["total"] != total or frame["size"] != payload_size \
			or frame["digest"] != digest_result[1]:
		_parts.erase(generation)
		return
	frame["parts"][index] = data_result[1]
	if frame["parts"].size() != total:
		return
	var payload := PackedByteArray()
	for part_index in total:
		if not frame["parts"].has(part_index):
			return
		payload.append_array(frame["parts"][part_index])
	if payload.size() != payload_size or MigrationState.digest(payload) != frame["digest"]:
		_parts.erase(generation)
		return
	var decoded := MigrationState.decode(payload)
	if not decoded.is_empty():
		_latest = decoded
		_received_ms = Time.get_ticks_msec()
	_parts.clear()

func is_fresh() -> bool:
	return not _latest.is_empty() and _received_ms >= 0 \
		and Time.get_ticks_msec() - _received_ms <= MigrationState.MAX_AGE_MS

func latest() -> Dictionary:
	return _latest.duplicate(true) if is_fresh() else {}
