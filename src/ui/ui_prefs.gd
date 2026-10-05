class_name UiPrefs
extends RefCounted
## Small per-device interface choices, kept beside the difficulty in
## user://game.cfg. Loaded once; each save keeps the file's other keys.

const PATH := "user://game.cfg"

static var _skip_quit_confirm: bool = false
static var _loaded := false

## "次回から確認しない" was ticked on the quit question.
static func skip_quit_confirm() -> bool:
	_load()
	return _skip_quit_confirm

static func set_skip_quit_confirm(value: bool) -> void:
	_load()
	_skip_quit_confirm = value
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # keep any other keys; a missing file is fine
	cfg.set_value("ui", "skip_quit_confirm", value)
	cfg.save(PATH)

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		_skip_quit_confirm = bool(cfg.get_value("ui", "skip_quit_confirm", false))

## For the probes: forget what was read so the file is read again.
static func reload() -> void:
	_loaded = false
	_skip_quit_confirm = false
