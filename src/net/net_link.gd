class_name NetLink
extends Node
## Where a connection attempt has got to, and the record of how it got there.
##
## There was no such place before. "Are we connected" was spread across a
## transport's socket state, a session's silence counter, a panel's status
## label and whether a node happened to exist -- and the four of them could
## disagree. A device sat in a dead room with a closed socket while the panel
## said "connecting", because nothing owned the question.
##
## One object owns it now. Everything that changes the answer calls `enter`,
## everything that displays it reads `phase`, and every transition is kept with
## a timestamp so the diagnostic can say what happened rather than guess.

## The seven states a connection can be in, and they are deliberately
## distinguishable: the difference between WAITING_PEER (we are fine, the other
## player has not pressed their button yet) and RECONNECTING (our own link is
## down) is the single most misread thing in this whole system.
enum Phase {
	IDLE,          ## nothing running
	DIALLING,      ## opening the socket to the relay
	WAITING_PEER,  ## we are in the room, alone
	HANDSHAKING,   ## both here; agreeing on build and tick
	PLAYING,       ## the game is running
	RECONNECTING,  ## our link went down and is being re-dialled
	FAILED,        ## given up; the player has to act
}

const LABELS := {
	Phase.IDLE: "未接続",
	Phase.DIALLING: "接続中",
	Phase.WAITING_PEER: "相手を待っています",
	Phase.HANDSHAKING: "ゲーム開始を確認中",
	Phase.PLAYING: "プレイ中",
	Phase.RECONNECTING: "再接続中",
	Phase.FAILED: "失敗",
}

## Everything this device remembers about networking lives in one file, and
## this class owns it. Two owners is what broke it: the connect screen wrote the
## relay URL by building a FRESH ConfigFile and saving that, which is a file
## containing one key -- so saving a relay address silently deleted the client
## id sitting next to it, and the device came back from the next restart as a
## stranger the relay had never seen. Read, change the one key, write.
const SETTINGS_PATH := "user://net.cfg"

## What this device remembers, by key. Reading is cheap and always fresh: these
## are a handful of bytes read at a button press, never in a frame.
static func recall(key: String, fallback: String = "") -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return fallback
	return String(cfg.get_value("net", key, fallback))

## Changes ONE key and leaves every other one alone.
static func remember(key: String, value: String) -> void:
	var cfg := ConfigFile.new()
	# Not an error: the first write to a device that has never saved anything
	# lands here, and starting from an empty file is exactly right.
	cfg.load(SETTINGS_PATH)
	cfg.set_value("net", key, value)
	cfg.save(SETTINGS_PATH)

## How many transitions to keep. A session that reconnects all evening should
## not grow without bound, and the diagnostic only ever shows the tail.
const JOURNAL_MAX: int = 60

signal phase_changed(phase: int, detail: String)

var phase: int = Phase.IDLE

## This attempt, not this room: pressing the button twice makes two attempts at
## the same room code, and the journal has to be able to tell them apart.
var attempt_id: String = ""
var room_code: String = ""
## What this device ASKED to be. The relay's answer can differ, and the gap
## between the two is exactly the "we are each alone in a different room"
## failure -- so both are recorded rather than only the answer.
var desired_role: String = ""
var relay_role: String = ""

var dialled_at_ms: int = -1
var joined_at_ms: int = -1
var handshaken_at_ms: int = -1

var close_code: int = -1
var close_reason: String = ""
var last_error: String = ""
var reconnects: int = 0

var _journal: Array[Dictionary] = []

# --------------------------------------------------------------------- state

## True while an attempt is in flight or a game is running. The connect screen
## refuses to start another one while this holds, which is what stops a second
## tap on "join" from building a second ClientSession beside the first.
func busy() -> bool:
	return phase != Phase.IDLE and phase != Phase.FAILED

func enter(next: int, detail: String = "") -> void:
	# A repeat of the same phase is a no-op rather than a journal entry: the
	# watchdog re-enters RECONNECTING every retry and the log would be nothing
	# else. The retry count carries that instead.
	if next == phase and detail.is_empty():
		return
	phase = next
	match next:
		Phase.DIALLING:
			dialled_at_ms = Time.get_ticks_msec()
		Phase.WAITING_PEER:
			if joined_at_ms < 0:
				joined_at_ms = Time.get_ticks_msec()
		Phase.PLAYING:
			if handshaken_at_ms < 0:
				handshaken_at_ms = Time.get_ticks_msec()
	_write("→ %s%s" % [LABELS.get(next, "?"), "" if detail.is_empty() else "  " + detail])
	phase_changed.emit(next, detail)

## A fact worth keeping that is not a change of state.
func note(text: String) -> void:
	_write(text)

func _write(text: String) -> void:
	_journal.append({"ms": Time.get_ticks_msec(), "text": text})
	while _journal.size() > JOURNAL_MAX:
		_journal.pop_front()

## Begins a fresh attempt. Everything measured about the previous one is
## cleared, because a report that mixes two attempts is worse than no report.
func begin(code: String, role: String) -> void:
	attempt_id = _short_id()
	room_code = code
	desired_role = role
	relay_role = ""
	dialled_at_ms = -1
	joined_at_ms = -1
	handshaken_at_ms = -1
	close_code = -1
	close_reason = ""
	last_error = ""
	reconnects = 0
	_journal.clear()
	_write(TranslationServer.translate("試行 %s  部屋 %s  希望役割 %s") % [attempt_id, code, role])
	enter(Phase.DIALLING)

func finish() -> void:
	enter(Phase.IDLE)

# ---------------------------------------------------------------- who we are

## A name for this device that survives a restart.
##
## The relay hands out roles by arrival order, which is right the first time
## and wrong every time after: a player whose app was killed mid-game comes
## back as "whoever arrived second" while their own dead socket still holds the
## first slot. With an id, the room can recognise the returning player, close
## the socket they left behind and give them their role back.
## Set from the command line, and it wins over the saved one.
##
## Two copies of the game on ONE machine share user:// and therefore share the
## saved id, and the relay -- correctly -- reads a second arrival carrying an id
## it already has as the first player coming back, so it closes the socket that
## id left behind. That is exactly right for a phone whose app was killed, and
## exactly wrong for two test processes, which then evict each other for as long
## as they both keep trying. tools/duet.sh gives each of them a name.
##
## It is not only a test hook. Two devices CAN end up sharing an id in the wild
## -- a restored backup carries user:// with it -- and the symptom is the pair
## endlessly knocking each other out of the room with nothing on screen to say
## why. Being able to say what this device calls itself, and to give it a
## different name, is the first thing anybody would want then.
static var _forced_id: String = ""

static func use_client_id(id: String) -> void:
	_forced_id = id

static func client_id() -> String:
	if not _forced_id.is_empty():
		return _forced_id
	for arg in OS.get_cmdline_user_args():
		if _forced_id == "--pending":
			_forced_id = arg
			return _forced_id
		if arg == "--client-id":
			_forced_id = "--pending"
	# A trailing --client-id with nothing after it is a typo, not a name.
	if _forced_id == "--pending":
		_forced_id = ""
	var saved := recall("client_id")
	if saved.length() >= 8:
		return saved
	var made := _short_id() + _short_id()
	remember("client_id", made)
	return made

static func _short_id() -> String:
	const ALPHABET := "23456789abcdefghjkmnpqrstuvwxyz"
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out := ""
	for _i in range(6):
		out += ALPHABET[rng.randi_range(0, ALPHABET.length() - 1)]
	return out

# -------------------------------------------------------------------- report

## Everything this object knows, for the on-device diagnostic. Facts only: a
## value that was never measured says so rather than reading as zero.
func lines() -> Array[String]:
	var out: Array[String] = []
	out.append(TranslationServer.translate("状態: %s") % LABELS.get(phase, "?"))
	out.append(TranslationServer.translate("試行ID: %s / 部屋: %s") % [
		attempt_id if not attempt_id.is_empty() else "（なし）",
		room_code if not room_code.is_empty() else "（なし）"])
	out.append(TranslationServer.translate("希望役割: %s / 中継が返した役割: %s") % [
		desired_role if not desired_role.is_empty() else "（未指定）",
		relay_role if not relay_role.is_empty() else "（未受信）"])
	out.append(TranslationServer.translate("接続開始: %s") % _stamp(dialled_at_ms))
	out.append(TranslationServer.translate("部屋に入った: %s") % _stamp(joined_at_ms))
	out.append(TranslationServer.translate("ゲーム開始の確認: %s") % _stamp(handshaken_at_ms))
	if close_code >= 0 or not close_reason.is_empty():
		out.append(TranslationServer.translate("切断: コード %d / 理由 %s") % [close_code,
			close_reason if not close_reason.is_empty() else "（なし）"])
	out.append(TranslationServer.translate("最後のエラー: %s") % (last_error if not last_error.is_empty() else "（なし）"))
	out.append(TranslationServer.translate("再接続回数: %d") % reconnects)
	return out

func journal_lines() -> Array[String]:
	var out: Array[String] = []
	var base: int = int(_journal[0]["ms"]) if not _journal.is_empty() else 0
	for entry in _journal:
		out.append("  +%6.2fs  %s" % [float(int(entry["ms"]) - base) / 1000.0,
			String(entry["text"])])
	return out

func _stamp(ms: int) -> String:
	if ms < 0:
		return "まだ"
	if dialled_at_ms < 0:
		return "%.2fs" % (float(ms) / 1000.0)
	return TranslationServer.translate("開始から %.2fs") % (float(ms - dialled_at_ms) / 1000.0)
