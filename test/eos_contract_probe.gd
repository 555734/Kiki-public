extends Node
## Fast CI contract for the EOS-only wire additions. The historical full logic
## suite has unrelated assertions for the retired Cloudflare UI, so native
## packaging runs this focused gate alongside the existing smoke probes.

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _ready() -> void:
	check(EosCoopLobby.valid_code("012345"), "leading-zero room code")
	check(not EosCoopLobby.valid_code("12345"), "short room code rejected")
	check(not EosCoopLobby.valid_code("12A456"), "non-decimal room code rejected")

	var blob := PackedByteArray()
	blob.resize(2505)
	for i in blob.size():
		blob[i] = i & 0xff
	var encoded := var_to_bytes({
		"version": MigrationState.VERSION,
		"captured_ms": Time.get_ticks_msec(),
		"stage": Stage.current(),
		"blob": blob,
	})
	var chunks := MigrationState.chunks(encoded, 7, 99)
	check(chunks.size() >= 3, "checkpoint splits into multiple chunks")
	var restored := PackedByteArray()
	var expected_digest := MigrationState.digest(encoded)
	for index in chunks.size():
		check(chunks[index].size() <= EosTransport.PAYLOAD_LIMIT,
			"chunk %d exceeds EOS payload cap" % index)
		var parsed := Protocol.reader(chunks[index])
		check(parsed[0] == Protocol.Msg.MIGRATION_CHUNK, "wrong message kind")
		var reader: StreamPeerBuffer = parsed[1]
		check(reader.get_u32() == 7 and reader.get_u32() == 99,
			"generation/tick mismatch")
		check(reader.get_u16() == index and reader.get_u16() == chunks.size(),
			"index/total mismatch")
		check(reader.get_u16() == encoded.size(), "payload size mismatch")
		var digest_result = reader.get_data(8)
		check(digest_result[0] == OK and digest_result[1] == expected_digest,
			"digest mismatch")
		var part = reader.get_data(reader.get_available_bytes())
		if part[0] == OK:
			restored.append_array(part[1])
	check(restored == encoded, "reassembled bytes differ")
	var decoded := MigrationState.decode(restored)
	check(decoded.get("blob", PackedByteArray()) == blob, "decoded frame differs")

	print("--- EOS contract probe: %d failed ---" % failures.size())
	for failure in failures:
		print("  FAIL  ", failure)
	get_tree().quit(0 if failures.is_empty() else 1)
