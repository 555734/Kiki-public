extends Node
## Who is allowed to play which stage, and the one place that answers it.
##
## Four states, and only four. See docs/monetization.md.
##
##   FREE   nothing bought        -- Stage.FREE_STAGES only
##   FULL   bought the full game  -- everything, forever
##   DEV    a developer           -- everything, renewed weekly
##   GUEST  playing with a buyer  -- everything, IN MEMORY, for this session
##
## The first three come from a token this device holds; the fourth comes from
## the partner over the wire and is never written to disk. That asymmetry is
## the whole of the friend pass: a guest borrows the unlock for as long as the
## room lasts and leaves with nothing.
##
## Nothing here can be talked into unlocking by editing a file or by a peer
## saying so. A token is signed by the entitlement server, carries the EOS
## ProductUserId it was issued to, and expires; and the puid it carries is
## checked against the puid the EOS LOBBY reports for that member, not against
## anything the peer claims. What this cannot defend against is a modified
## binary -- no client-side game can -- and docs/monetization.md says so rather
## than pretending otherwise.

signal changed

enum Level { FREE, GUEST, FULL, DEV }

const PATH := "user://entitlement.json"
const KEY_PATH := "res://entitlement_key.json"
## Bumped if the payload's shape ever changes. An unknown version is refused
## rather than guessed at.
const TOKEN_VERSION := 1
## A build whose key file still says this cannot validate anything, so it fails
## closed: every player is FREE and no token will ever unlock. That is the
## right way round -- a missing key must not open the game, and a release build
## with a placeholder key is caught by tools/verify.sh rather than by a player.
const PLACEHOLDER_MARKER := "PLACEHOLDER"
## How close to expiry a token gets before the game quietly asks for a new one.
const RENEW_WINDOW_SECONDS := 7 * 24 * 60 * 60

## The stored token, or "" when this device has bought nothing.
var _token: String = ""
var _claims: Dictionary = {}
## Granted by a partner for the length of one session. Never saved.
var _guest_until: float = 0.0
var _guest_from_puid: String = ""
## Swapped for a throwaway key by test/entitlement_probe.gd. Production builds
## never touch this: it is set from KEY_PATH at startup and left alone.
var _key: CryptoKey = null
var _key_is_placeholder: bool = true

func _ready() -> void:
	_load_key()
	_load_token()

# ------------------------------------------------------------------ the answer

func level() -> int:
	if _guest_until > Time.get_unix_time_from_system():
		return Level.GUEST
	if _claims.is_empty():
		return Level.FREE
	if float(_claims.get("exp", 0.0)) <= Time.get_unix_time_from_system():
		return Level.FREE
	return Level.DEV if String(_claims.get("kind", "")) == "dev" else Level.FULL

func unlocked() -> bool:
	return level() != Level.FREE

## Whether this device may play `which` right now. A guest counts; a guest's
## session ending takes it away again, which is what revoke_guest is for.
func can_play(which: int) -> bool:
	return Stage.is_free(which) or unlocked()

## Whether this device may CREATE a room on `which`.
##
## Deliberately stricter than can_play: a guest may not host. That is what
## stops a borrowed unlock from being lent on, and -- because an EOS lobby
## holds exactly two -- it is also what caps one purchase at one guest at a
## time without any server counting sessions.
func can_host(which: int) -> bool:
	if Stage.is_free(which):
		return true
	var lv := level()
	return lv == Level.FULL or lv == Level.DEV

## For the UI: whether to offer to sell anything at all.
func should_offer_purchase() -> bool:
	var lv := level()
	return lv == Level.FREE

func is_guest() -> bool:
	return level() == Level.GUEST

func expires_at() -> float:
	return float(_claims.get("exp", 0.0))

func kind() -> String:
	return String(_claims.get("kind", ""))

## True when the stored token is close enough to expiry to be worth renewing.
## Renewal is best effort and never blocks play -- see docs/monetization.md on
## what happens when the store's API is unreachable.
func wants_renewal() -> bool:
	if _claims.is_empty():
		return false
	return expires_at() - Time.get_unix_time_from_system() < RENEW_WINDOW_SECONDS

## What this device puts on the wire so a partner can see it is entitled.
## A guest has nothing to offer: the grant it holds is not its own.
func local_token() -> String:
	var lv := level()
	return _token if lv == Level.FULL or lv == Level.DEV else ""

# ------------------------------------------------------------------ the token

## Verify and store a token the entitlement server issued to THIS device.
## Returns false, and changes nothing, if it does not check out.
func install_token(token: String, puid: String) -> bool:
	var claims := verify(token, puid)
	if claims.is_empty():
		return false
	_token = token
	_claims = claims
	_save_token()
	changed.emit()
	return true

func clear_token() -> void:
	if _token.is_empty():
		return
	_token = ""
	_claims = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	changed.emit()

## Check a token's signature, shape and expiry, and -- when `expect_puid` is
## given -- that it was issued to that ProductUserId.
##
## Returns the claims, or an empty dictionary. There is no partial success:
## every caller treats {} as "no".
func verify(token: String, expect_puid: String = "") -> Dictionary:
	if _key == null or _key_is_placeholder or token.is_empty():
		return {}
	var parts := token.split(".", false)
	if parts.size() != 2:
		return {}
	var payload := _from_base64url(parts[0])
	var signature := _from_base64url(parts[1])
	if payload.is_empty() or signature.is_empty():
		return {}
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(payload)
	if not Crypto.new().verify(HashingContext.HASH_SHA256, hasher.finish(), signature, _key):
		return {}
	var parsed = JSON.parse_string(payload.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var claims: Dictionary = parsed
	if int(claims.get("v", 0)) != TOKEN_VERSION:
		return {}
	if not ["full", "dev"].has(String(claims.get("kind", ""))):
		return {}
	if float(claims.get("exp", 0.0)) <= Time.get_unix_time_from_system():
		return {}
	var token_puid := String(claims.get("puid", ""))
	if token_puid.is_empty():
		return {}
	# The one check that makes a copied token worthless.
	if not expect_puid.is_empty() and token_puid != expect_puid:
		return {}
	return claims

# ------------------------------------------------------------------ the guest

## Accept a partner's entitlement for the length of this session.
##
## `peer_puid` must come from the EOS lobby's member list, not from the packet:
## the packet is the thing being checked. `room_kind` must be a friend room --
## a public room, when matchmaking exists, hands out nothing no matter who it
## paired you with.
func grant_guest(token: String, peer_puid: String, room_kind: String) -> bool:
	if room_kind != "friend":
		return false
	if peer_puid.is_empty():
		return false
	var claims := verify(token, peer_puid)
	if claims.is_empty():
		return false
	_guest_from_puid = peer_puid
	# The grant cannot outlive the partner's own token, and it never outlives
	# the session: revoke_guest is called when the room ends either way.
	_guest_until = float(claims.get("exp", 0.0))
	changed.emit()
	return true

func revoke_guest() -> void:
	if _guest_until == 0.0 and _guest_from_puid.is_empty():
		return
	_guest_until = 0.0
	_guest_from_puid = ""
	changed.emit()

func guest_host_puid() -> String:
	return _guest_from_puid

## Check the stored token against who this device turns out to be.
##
## _load_token cannot do this: it runs at startup, and the ProductUserId is not
## known until EOS has logged in. So the token is loaded on its signature and
## its expiry, and is bound HERE, the moment there is an identity to bind it
## to. Without this step a copied user://entitlement.json would work on a
## second device, which is the one hole a signature alone does not close.
##
## A mismatch is not an accusation. A reinstall gives this device a new
## ProductUserId and its perfectly genuine token now names the old one; the
## token is dropped and Iap asks the server for a fresh one against the same
## store receipt, which is what "restore" is.
func bind_to(puid: String) -> void:
	if puid.is_empty() or _claims.is_empty():
		return
	if String(_claims.get("puid", "")) == puid:
		return
	clear_token()

# ------------------------------------------------------------------- internals

func _load_key() -> void:
	_key = null
	_key_is_placeholder = true
	if not FileAccess.file_exists(KEY_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(KEY_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var pem := String((parsed as Dictionary).get("public_key_pem", ""))
	if pem.is_empty() or pem.contains(PLACEHOLDER_MARKER):
		return
	var key := CryptoKey.new()
	if key.load_from_string(pem, true) != OK:
		return
	_key = key
	_key_is_placeholder = false

## Used by the probe to test verification without the production key, and by
## nothing else. It cannot widen anything: a token still has to be signed by
## whatever key is installed, and installing one is not something the shipped
## UI can do.
func use_key_for_testing(pem: String) -> bool:
	var key := CryptoKey.new()
	if key.load_from_string(pem, true) != OK:
		return false
	_key = key
	_key_is_placeholder = false
	return true

func has_key() -> bool:
	return _key != null and not _key_is_placeholder

func _load_token() -> void:
	_token = ""
	_claims = {}
	if not FileAccess.file_exists(PATH):
		return
	var raw := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var token := String((parsed as Dictionary).get("token", ""))
	# Re-verified on every launch rather than trusted because it is on our own
	# disk. Editing this file gets you a token whose signature does not check.
	var claims := verify(token)
	if claims.is_empty():
		return
	_token = token
	_claims = claims

func _save_token() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"token": _token}))
	file.close()

## Tokens travel as base64url so they survive a URL and a text field. Godot
## only offers standard base64, so the two characters that differ are swapped
## back before decoding and the padding is restored.
static func _from_base64url(text: String) -> PackedByteArray:
	var standard := text.replace("-", "+").replace("_", "/")
	while standard.length() % 4 != 0:
		standard += "="
	return Marshalls.base64_to_raw(standard)

static func _to_base64url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes) \
		.replace("+", "-").replace("/", "_").replace("=", "")
