class_name Options
extends RefCounted
## The handful of things a player can turn on and off, and the one place they
## are written down.
##
## Separate from ControlLayout, which owns where the buttons ARE, because these
## are not positions -- and separate from NetLink's file, which is about the
## connection. Three small stores, each with one owner, rather than one file
## that three classes take turns overwriting.
##
## Every write reads the file first and changes one key. That is not a style
## choice: a save that rebuilt the file from what one class happened to know
## about is exactly how this project deleted a device's own name (see
## NetLink.remember).

const PATH := "user://options.cfg"

## Sprinting without holding anything.
##
## A held sprint is two fingers on a phone: one on the stick, one on the dash
## button, and the jump button wants one of them. Turning this on gives the
## sprint away for free -- and the cost is that a runner who is always at top
## speed has a longer stopping distance, so the narrow places get harder. Both
## halves are checked in test/workshop_probe.gd: with this on, a one-block
## perch has to still be somewhere a runner can stop.
##
## A phone has no sprint button any more, so there it is always on: turning it
## off would leave a runner who can only walk.
static func auto_dash() -> bool:
	if touch_device():
		return true
	return _read("auto_dash", false)

static func touch_device() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")

static func set_auto_dash(on: bool) -> void:
	_write("auto_dash", on)

## Short horizontal travel for touch; movement acceleration still belongs to Runner.
static func responsive_touch() -> bool:
	return _read("responsive_touch", true)

static func set_responsive_touch(on: bool) -> void:
	_write("responsive_touch", on)

## Jump is intentionally dedicated to the JUMP button.  Keep this API so older
## UI/test code can call it, but never allow upward stick travel to become a
## jump source again.
static func stick_jump() -> bool:
	return false

static func set_stick_jump(_on: bool) -> void:
	_write("stick_jump", false)

# --------------------------------------------------------------------- store

## Cached, because these are read inside the movement code every frame and a
## file read per frame would be absurd. Written through, so the cache and the
## file cannot disagree.
static var _cache: Dictionary = {}
static var _loaded: bool = false

static func _read(key: String, fallback):
	_ensure_loaded()
	return _cache.get(key, fallback)

static func _write(key: String, value) -> void:
	_ensure_loaded()
	_cache[key] = value
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("play", key, value)
	cfg.save(PATH)

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in cfg.get_section_keys("play") if cfg.has_section("play") else []:
		_cache[key] = cfg.get_value("play", key)

## Test seam: back to the defaults, with the file left alone and not read again
## behind the test's back.
static func forget() -> void:
	_cache.clear()
	_loaded = true

## And the other direction: drop the cache and read the file next time, which is
## what "does the setting survive a restart" actually means.
static func reload() -> void:
	_cache.clear()
	_loaded = false

