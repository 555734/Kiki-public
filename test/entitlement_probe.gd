extends Node
## What the full-game purchase and the friend pass are allowed to do.
##
## The signing key here is generated when this probe starts and thrown away
## when it ends. It is not a back door and it is not the production key: the
## point is that Entitlement will only believe a token signed by whatever key
## is installed, so a test can install its own and then demonstrate that a
## token signed by NOTHING -- or by the right key but for the wrong device, or
## for a time that has passed -- is refused.
##
## What this cannot test is a real purchase. Nothing here talks to Google or
## Apple; the store round trip is the Worker's job and is covered by
## server/signaling/test.mjs. See docs/monetization.md for the list of things
## that only a device and a store account can prove.

const MainScene: PackedScene = preload("res://src/main.tscn")
const DAY := 86400.0

var failures: Array[String] = []
var main: Node2D = null
var _crypto := Crypto.new()
var _key: CryptoKey = null
## A second key, so "signed by somebody, just not us" can be told apart from
## "not signed at all".
var _wrong_key: CryptoKey = null

func check(ok: bool, message: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	_key = _crypto.generate_rsa(2048)
	_wrong_key = _crypto.generate_rsa(2048)
	check(Entitlement.use_key_for_testing(_key.save_to_string(true)),
		"the probe's throwaway public key installs")

	_free_player()
	_a_bought_copy()
	_a_developer()
	_tampering()
	await _the_friend_pass()
	await _the_pass_expires_with_the_room()
	_not_in_a_public_room()

	if main != null:
		main.queue_free()
		await get_tree().process_frame
	Entitlement.clear_token()
	Entitlement.revoke_guest()
	Stage.use(Stage.Which.GREENFIELD)
	if failures.is_empty():
		print("entitlement probe: all checks passed")
		get_tree().quit(0)
	else:
		for f in failures:
			push_error("entitlement probe: " + f)
		get_tree().quit(1)

# ------------------------------------------------------------------- the rules

func _free_player() -> void:
	_become_free()
	check(Entitlement.level() == Entitlement.Level.FREE, "a new install is a free player")
	check(Entitlement.can_play(Stage.Which.GREENFIELD)
		and Entitlement.can_play(Stage.Which.HORROR),
		"a free player can play 1-1 and 1-2")
	check(Entitlement.can_host(Stage.Which.GREENFIELD)
		and Entitlement.can_host(Stage.Which.HORROR),
		"and can make a room on either of them")
	var paid := [Stage.Which.SKYWARD_RUINS, Stage.Which.SEA, Stage.Which.SWAMP]
	var blocked := true
	var unhostable := true
	for which in paid:
		blocked = blocked and not Entitlement.can_play(which)
		unhostable = unhostable and not Entitlement.can_host(which)
	check(blocked, "a free player cannot play 1-3, 1-4 or 1-5 alone")
	# The other half of requirement 5: two free players cannot put a paid stage
	# on the wire at all, because neither of them can create the room.
	check(unhostable, "and cannot create a room on one, so two free players cannot start it")
	check(Entitlement.should_offer_purchase(), "so the game offers to sell them the full version")

func _a_bought_copy() -> void:
	_become_free()
	var token := _mint("full", "this-device", Time.get_unix_time_from_system() + 30.0 * DAY)
	check(Entitlement.install_token(token, "this-device"), "a valid purchase token installs")
	check(Entitlement.level() == Entitlement.Level.FULL, "and makes this a bought copy")
	var all := true
	for which in Stage.Which.values():
		all = all and Entitlement.can_play(which) and Entitlement.can_host(which)
	check(all, "which plays and hosts every stage there is")
	check(not Entitlement.should_offer_purchase(),
		"and is never shown the purchase screen again")
	check(Entitlement.local_token() == token, "the buyer's token is what goes on the wire")

	# Restoring is re-installing: the server hands back the same entitlement
	# for the same store account, so a reinstall is not a special case.
	Entitlement.clear_token()
	check(Entitlement.level() == Entitlement.Level.FREE, "clearing it goes back to free")
	check(Entitlement.install_token(token, "this-device"),
		"and the same token restores the purchase")
	check(Entitlement.level() == Entitlement.Level.FULL, "restore returns the full version")

func _a_developer() -> void:
	_become_free()
	var token := _mint("dev", "this-device", Time.get_unix_time_from_system() + 7.0 * DAY)
	check(Entitlement.install_token(token, "this-device"), "a developer token installs")
	check(Entitlement.level() == Entitlement.Level.DEV, "and is its own state, not a fake purchase")
	check(Entitlement.can_play(Stage.Which.SWAMP) and Entitlement.can_host(Stage.Which.SWAMP),
		"a developer plays and hosts everything")
	check(not Entitlement.should_offer_purchase(), "and is not sold anything")
	# The reason it is a separate state: a dev token is short-lived, so pulling
	# DEV_ENROL_SECRET out of the Worker ends developer access by itself.
	check(Entitlement.expires_at() - Time.get_unix_time_from_system() <= 7.0 * DAY + 60.0,
		"a developer token is short-lived, so revoking it needs no app update")

func _tampering() -> void:
	_become_free()
	var now := Time.get_unix_time_from_system()

	check(not Entitlement.install_token("", "this-device"), "an empty token is not a purchase")
	check(not Entitlement.install_token("not-a-token", "this-device"),
		"nor is a string that is not a token")

	var good := _mint("full", "this-device", now + 30.0 * DAY)
	check(not Entitlement.install_token(_bend(good), "this-device"),
		"a token with one byte of the signature changed is refused")

	check(not Entitlement.install_token(
			_mint_with(_wrong_key, "full", "this-device", now + 30.0 * DAY), "this-device"),
		"a token signed by the wrong key is refused")

	# The check that makes a stolen token worthless: it names the device it was
	# issued to, and that name is compared against who this device actually is.
	check(not Entitlement.install_token(
			_mint("full", "somebody-else", now + 30.0 * DAY), "this-device"),
		"somebody else's token is refused on this device")

	check(not Entitlement.install_token(_mint("full", "this-device", now - 60.0), "this-device"),
		"an expired token is refused")

	check(not Entitlement.install_token(
			_mint("premium", "this-device", now + 30.0 * DAY), "this-device"),
		"a token claiming a kind that does not exist is refused")

	check(Entitlement.level() == Entitlement.Level.FREE,
		"after all of that this device is still a free player")

	# And the file on disk is not believed either. Writing a plausible-looking
	# entitlement by hand is the first thing anybody tries.
	var forged := FileAccess.open(Entitlement.PATH, FileAccess.WRITE)
	forged.store_string(JSON.stringify({"token": "made.up", "kind": "full"}))
	forged.close()
	Entitlement._load_token()
	check(Entitlement.level() == Entitlement.Level.FREE,
		"a hand-written user:// entitlement file unlocks nothing")
	Entitlement.clear_token()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Entitlement.PATH))

	# And a REAL token, copied off the device it was issued to. The signature
	# checks out and the expiry is fine; the only thing wrong with it is whose
	# it is, and that is not known until EOS has said who this device is.
	var borrowed := _mint("full", "another-persons-device", now + 30.0 * DAY)
	var file := FileAccess.open(Entitlement.PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"token": borrowed}))
	file.close()
	Entitlement._load_token()
	check(Entitlement.level() == Entitlement.Level.FULL,
		"a copied token loads before there is an identity to check it against")
	Entitlement.bind_to("this-device")
	check(Entitlement.level() == Entitlement.Level.FREE,
		"and is dropped the moment this device turns out to be somebody else")
	Entitlement.bind_to("")
	Entitlement.clear_token()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Entitlement.PATH))

# ------------------------------------------------------------- the friend pass

## A free player joins a buyer's friend room and plays a paid stage.
##
## Host and guest are the same process here, and there is only one Entitlement
## autoload in a process, so the two sides are driven one at a time: first that
## a buyer puts its token on the wire, then that a free player who receives it
## is let in. Both halves run the shipped code -- HostSession's HELLO branch
## and ClientSession's WELCOME branch -- rather than calling grant_guest
## directly, because the thing worth testing is that those branches take their
## facts from the lobby and not from the packet.
func _the_friend_pass() -> void:
	await _boot(Stage.Which.SWAMP)

	# --- the buyer's side: does the entitlement actually leave the device? ---
	_become_free()
	var buyer_token := _mint("full", "buyer-puid", Time.get_unix_time_from_system() + 30.0 * DAY)
	check(Entitlement.install_token(buyer_token, "buyer-puid"), "the buyer's device is a buyer")
	var pair := LoopbackTransport.pair(0.0)
	var host_side: LoopbackTransport = pair[0]
	var guest_side: LoopbackTransport = pair[1]
	host_side.stub_identity = {"puid": "guest-puid", "room_kind": "friend"}
	guest_side.stub_identity = {"puid": "buyer-puid", "room_kind": "friend"}
	var host := HostSession.new()
	host.main = main
	host.transport = host_side
	add_child(host)
	await _frames(2)
	guest_side.send(NetTransport.Channel.CONTROL,
		NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.hello("guest-device", Stage.current(), "guardian", ""))
	await _pump(pair, 4)
	check(_welcome_token(guest_side) == buyer_token,
		"the buyer's token travels on the handshake the reconnect path already uses")
	host.queue_free()
	await _frames(2)

	# --- the guest's side: a free player receiving that token ---
	_become_free()
	check(not Entitlement.can_play(Stage.Which.SWAMP),
		"the guest starts out unable to play 1-5")
	var client_pair := LoopbackTransport.pair(0.0)
	var client_side: LoopbackTransport = client_pair[0]
	var remote: LoopbackTransport = client_pair[1]
	client_side.stub_identity = {"puid": "buyer-puid", "room_kind": "friend"}
	var session := ClientSession.new()
	session.main = main
	session.transport = client_side
	add_child(session)
	await _frames(2)
	remote.send(NetTransport.Channel.CONTROL,
		NetTransport.Reliability.RELIABLE_ORDERED,
		Protocol.welcome(Clock.tick, "buyer-device", buyer_token))
	await _pump(client_pair, 4)
	check(Entitlement.level() == Entitlement.Level.GUEST,
		"a free player in a buyer's friend room becomes a guest")
	check(Entitlement.can_play(Stage.Which.SWAMP) and Entitlement.can_play(Stage.Which.SEA),
		"and can play every paid stage while the room lasts")
	# The borrowed unlock cannot be lent on, which is what caps one purchase at
	# one guest without any server counting sessions.
	check(not Entitlement.can_host(Stage.Which.SWAMP),
		"but cannot create a paid room of their own with it")
	check(Entitlement.guest_host_puid() == "buyer-puid", "and knows whose pass it is holding")
	check(not FileAccess.file_exists(Entitlement.PATH),
		"nothing about the pass is written to disk")

	session.queue_free()
	await _frames(2)

func _the_pass_expires_with_the_room() -> void:
	check(Entitlement.level() == Entitlement.Level.FREE,
		"when the room ends the guest is a free player again")
	check(not Entitlement.can_play(Stage.Which.SWAMP),
		"and cannot replay the paid stage on their own afterwards")

## The rule that is here for the matchmaking that does not exist yet: a pass is
## a thing a friend hands you, not a thing you win by being paired with a
## stranger who happens to own the game.
func _not_in_a_public_room() -> void:
	_become_free()
	var token := _mint("full", "buyer-puid", Time.get_unix_time_from_system() + 30.0 * DAY)
	check(not Entitlement.grant_guest(token, "buyer-puid", "public"),
		"a public room hands out no pass, however entitled the other player is")
	check(not Entitlement.grant_guest(token, "buyer-puid", ""),
		"and a room that will not say what kind it is hands out none either")
	check(not Entitlement.grant_guest(token, "", "friend"),
		"a partner the lobby cannot name gets nowhere")
	# The one that matters most: the token is real, the room is right, and the
	# claim is still refused because the lobby says that member is somebody else.
	check(not Entitlement.grant_guest(token, "a-different-member", "friend"),
		"a real token replayed by a different member of the room is refused")
	check(Entitlement.grant_guest(token, "buyer-puid", "friend"),
		"the same token from the member it was issued to is accepted")
	Entitlement.revoke_guest()
	check(Entitlement.level() == Entitlement.Level.FREE, "and revoking it ends the grant")

# -------------------------------------------------------------------- plumbing

func _become_free() -> void:
	Entitlement.clear_token()
	Entitlement.revoke_guest()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Entitlement.PATH))
	Entitlement._load_token()

func _mint(kind: String, puid: String, exp: float) -> String:
	return _mint_with(_key, kind, puid, exp)

func _mint_with(key: CryptoKey, kind: String, puid: String, exp: float) -> String:
	var payload := JSON.stringify({
		"v": Entitlement.TOKEN_VERSION,
		"kind": kind,
		"puid": puid,
		"plat": "test",
		"iat": Time.get_unix_time_from_system(),
		"exp": exp,
	}).to_utf8_buffer()
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(payload)
	var signature := _crypto.sign(HashingContext.HASH_SHA256, hasher.finish(), key)
	return _b64(payload) + "." + _b64(signature)

## The same token with one bit of its signature turned over.
func _bend(token: String) -> String:
	var parts := token.split(".", false)
	var signature := Entitlement._from_base64url(parts[1])
	signature[0] = signature[0] ^ 0x01
	return parts[0] + "." + _b64(signature)

static func _b64(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes) \
		.replace("+", "-").replace("/", "_").replace("=", "")

## The token the host put on its WELCOME, read back off the wire.
func _welcome_token(side: LoopbackTransport) -> String:
	for packet in side.poll():
		# Only the event channel: a snapshot carries no message kind, and one
		# whose first byte happens to be 2 reads exactly like a WELCOME. That
		# is what this function did on its first attempt.
		if int(packet["channel"]) != NetTransport.Channel.EVENT:
			continue
		var parsed := Protocol.reader(packet["payload"])
		if int(parsed[0]) != Protocol.Msg.WELCOME:
			continue
		var b: StreamPeerBuffer = parsed[1]
		b.get_u32()
		b.get_utf8_string()
		return Protocol.opt_string(b)
	return ""

func _boot(which: int) -> void:
	Stage.use(which)
	if main != null:
		main.free()
	main = MainScene.instantiate()
	add_child(main)
	await _frames(4)
	var panel := main.get_node_or_null("NetPanel")
	if panel != null:
		panel.queue_free()
		await _frames(2)
	main.input_hub.scripted = true

func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame

func _pump(pair: Array, frames: int) -> void:
	for _i in frames:
		for side in pair:
			(side as LoopbackTransport).advance(1.0 / 60.0)
		await get_tree().process_frame
