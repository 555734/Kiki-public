extends Node
## Everything the game says out loud.
##
## Wired entirely to the event bus and to nothing else. No gameplay script calls
## a play function, which is the point: the events already describe what
## happened and who it happened to, so the sound is one more listener rather
## than a second copy of the game's logic scattered through it. Muting the game
## is removing this node.
##
## It works the same on both devices for the same reason. The guardian's phone
## raises these signals from the host's relayed events and from the snapshots it
## interpolates (see ClientSession), so the guardian hears the runner land even
## though nothing on their device simulated the landing.
##
## Sounds come from tools/make_audio.py -- synthesized, because no audio was
## supplied. See that file for what that does and does not buy.

const BASE := "res://assets/audio/"

## Enough voices that a busy moment -- a shot connecting on an enemy over a
## coin while the runner lands -- does not cut itself off, and few enough to be
## free on a phone.
const VOICES: int = 14

## The stage loop plus a second layer mixed on top of it when things get
## dangerous. Not a crossfade: both play from the same position, so the music
## gets more urgent without restarting or changing key.
const DRIVE_ATTACK := 1.2
const DRIVE_RELEASE := 2.6

var _voices: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary = {}

var _music: AudioStreamPlayer = null
var _drive: AudioStreamPlayer = null
var _drive_level: float = 0.0
var _drive_target: float = 0.0

var _runner: Node2D = null
var _hp: int = Balance.RUNNER_MAX_HP

## Rate limits. Several of these events can fire on one frame -- three coins in
## an arc, a burst of pellets hitting a wall -- and the same sample started four
## times in four milliseconds is a click, not four sounds.
var _last_played: Dictionary = {}
const REPEAT_GAP := 0.045

## Test seam. Headless runs on a dummy audio driver, so "did it make a noise"
## is unanswerable there -- but "did the right event reach the right sound" is
## the part that actually breaks, and this is how the suite reads it.
var last_key: String = ""

## Every sound this node can ask for. Listed rather than inferred so a typo in
## one of the lambdas below is a failing check instead of a silent event.
const KEYS := [
	"jump", "land", "dash", "hurt", "die", "respawn", "warp",
	"coin", "spring",
	"place_platform", "place_wall", "place_warp", "refuse",
	"shot", "hit", "enemy_die", "scope_up", "scope_down",
	"switch", "gate", "checkpoint", "countdown",
	"rescue_1", "rescue_2", "rescue_3",
	"stage_clear", "game_over",
	"music_stage", "music_drive",
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)

	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_drive = AudioStreamPlayer.new()
	_drive.bus = "Music"
	add_child(_drive)

	_connect_events()
	_start_music()

## Two buses so music and effects can be balanced against each other, and so
## there is somewhere obvious to hang a volume slider later.
func _make_buses() -> void:
	for name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(name) >= 0:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, name)
		AudioServer.set_bus_send(index, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -7.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), -2.0)

func _connect_events() -> void:
	Events.runner_spawned.connect(func(who: Node2D) -> void: _runner = who)
	Events.runner_jumped.connect(func() -> void: play("jump", 0.0, 0.06))
	Events.runner_landed.connect(func(hard: bool) -> void:
		play("land", 0.0 if hard else 2.0, 0.05, 1.0 if hard else 0.6))
	Events.runner_damaged.connect(_on_damaged)
	Events.runner_died.connect(func(_cause: String) -> void:
		play("die")
		play("game_over", 0.0, 0.0, 0.9)
		_drive_target = 0.0)
	Events.runner_respawned.connect(func(_i: int) -> void: play("respawn"))
	Events.runner_warped.connect(func(_from: Vector2, _to: Vector2) -> void:
		play("warp"))

	Events.coin_collected.connect(func(_at: Vector2) -> void: play("coin", 0.0, 0.10))
	Events.spring_bounced.connect(func(_at: Vector2) -> void: play("spring"))
	Events.runner_launched.connect(func(_at: Vector2) -> void: play("spring"))
	Events.runner_wall_jumped.connect(func(_at: Vector2, _away: int) -> void: play("jump"))
	# Not the hit sound. A refused shot has to be audibly different from a
	# connecting one or the guardian cannot tell, in the moment, which it was.
	Events.shot_blocked.connect(func(_at: Vector2) -> void: play("refuse"))
	Events.crystal_taken.connect(func(_id: int, _at: Vector2, _a: float) -> void:
		play("checkpoint"))

	Events.ability_used.connect(_on_ability_used)
	Events.ability_refused.connect(func(_slot: int, _r: String) -> void:
		play("refuse"))
	Events.shot_fired.connect(func(_f: Vector2, _t: Vector2, hit: bool) -> void:
		play("shot")
		if hit:
			play("hit", 0.0, 0.0, 0.9))
	Events.enemy_killed.connect(func(_e: Node2D, _by: String) -> void:
		play("enemy_die"))
	Events.scope_state_changed.connect(func(active: bool, _z: float) -> void:
		play("scope_up" if active else "scope_down"))

	Events.switch_activated.connect(func(id: String) -> void:
		play("switch" if not id.ends_with(":off") else "gate", 0.0, 0.0, 0.8))
	Events.checkpoint_reached.connect(func(_i: int) -> void: play("checkpoint"))
	Events.stage_cleared.connect(func(_stats: Dictionary) -> void:
		play("stage_clear")
		_fade_music_out())
	Events.countdown_started.connect(func() -> void: play("countdown"))
	Events.rescue_scored.connect(func(tier: int, _at: Vector2) -> void:
		play("rescue_%d" % clampi(tier, 1, 3)))

## One sound, three pitches, so the runner knows which tool arrived behind them
## without turning round.
func _on_ability_used(slot: int, _at: Vector2) -> void:
	match slot:
		1: play("place_platform")
		2: play("place_wall")
		4: play("place_warp")

func _on_damaged(hp: int, _max: int) -> void:
	# Only on the way down. runner_damaged is also raised on a respawn to reset
	# the hearts, and a hurt sound for getting health back reads as a bug.
	if hp < _hp:
		play("hurt")
	_hp = hp

# ---------------------------------------------------------------------- sfx

## `semitones` retunes without a second file, `spread` randomises by that many
## semitones so a repeated sound does not become a machine gun.
func play(key: String, semitones: float = 0.0, spread: float = 0.0,
		volume: float = 1.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(key, -99.0)) < REPEAT_GAP:
		return
	_last_played[key] = now
	last_key = key
	var stream := _stream(key)
	if stream == null:
		return
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = stream
	var cents := semitones + (randf() * 2.0 - 1.0) * spread
	p.pitch_scale = pow(2.0, cents / 12.0)
	p.volume_db = linear_to_db(clampf(volume, 0.01, 2.0))
	p.play()

func _stream(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	var path := BASE + key + ".wav"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[key] = stream
	if stream == null:
		push_warning("no sound for '%s'" % key)
	return stream

## Both layers running, in sync. If either stream failed to load the music is
## silently absent, which is exactly the kind of thing nobody notices until a
## playtest.
func music_running() -> bool:
	return _music != null and _drive != null and _music.playing and _drive.playing

# -------------------------------------------------------------------- music

func _start_music() -> void:
	var base := _stream("music_stage")
	var drive := _stream("music_drive")
	if base == null or drive == null:
		return
	# The loop points are set here rather than in the import: the two layers have
	# to wrap at exactly the same sample or they drift apart within a minute,
	# and the generator guarantees they are the same length.
	for s in [base, drive]:
		if s is AudioStreamWAV:
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(s as AudioStreamWAV).loop_begin = 0
			(s as AudioStreamWAV).loop_end = (s as AudioStreamWAV).data.size() / 2
	_music.stream = base
	_drive.stream = drive
	_music.play()
	_drive.play()
	_drive.volume_db = -60.0

func _fade_music_out() -> void:
	_drive_target = 0.0
	var tween := create_tween()
	tween.tween_property(_music, "volume_db", -60.0, 1.4)

func _process(delta: float) -> void:
	_update_drive(delta)

## How much of the second layer to hear. Driven by the two things that actually
## mean trouble -- the runner is on their last hit, or they are falling with
## nothing under them -- rather than by proximity to enemies, which lights up
## every time they walk past a turret they have already dealt with.
func _update_drive(delta: float) -> void:
	if is_instance_valid(_runner):
		var falling: bool = _runner.velocity.y > Balance.RUNNER_TERMINAL_VELOCITY * 0.5
		var last_hit: bool = _hp <= 1
		_drive_target = 1.0 if (falling or last_hit) else 0.0
	var rate := delta / (DRIVE_ATTACK if _drive_target > _drive_level else DRIVE_RELEASE)
	_drive_level = move_toward(_drive_level, _drive_target, rate)
	_drive.volume_db = linear_to_db(maxf(_drive_level, 0.001))
