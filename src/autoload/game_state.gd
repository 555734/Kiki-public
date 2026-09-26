extends Node
## Run progression: checkpoints, retries, and the team stats the stage-clear
## screen reports. Chapter 7 asks for a single *team* rating rather than one
## score per player, so everything here is deliberately shared.

var checkpoint_index: int = 0
var checkpoint_position: Vector2 = Vector2.ZERO
var stage_start_position: Vector2 = Vector2.ZERO

## Crystals already collected, by net_id.
##
## Held here rather than on the nodes because it has to survive the level being
## rebuilt -- a respawn throws every pickup away and makes new ones, and a
## crystal the runner fetched before the checkpoint must not come back with
## them. It is also what a reconnecting guardian is sent so their screen agrees.
var crystals_taken: Dictionary = {}

## The Keeper's remaining wounds, or -1 before the fight has started.
##
## Held here for the same reason crystals_taken is: a respawn frees the whole
## dynamic layer and builds it again, so a boss that remembered its own damage
## would come back whole. Written only when an ACT changes, which is what makes
## a death cost at most the two wounds of the act it happened in -- a boss that
## fully heals would throw away six cycles for one mistake, and this game
## returns the runner in 0.45s precisely so that mistakes stay small.
var boss_hp: int = -1

var deaths: int = 0
var rescues: int = 0          ## runner landed on a platform placed mid-air
## Graded catches, indexed by tier. The clear screen reports the best one,
## because "you caught them four times" and "you caught one of them with two
## frames to spare" are different sentences.
var rescue_tiers: Array[int] = [0, 0, 0, 0]
var enemies_sniped: int = 0
var enemies_stomped: int = 0
var shots_blocked: int = 0    ## projectiles a wall ate
var elapsed: float = 0.0
var running: bool = false

func _ready() -> void:
	Events.runner_died.connect(_on_runner_died)
	Events.checkpoint_reached.connect(_on_checkpoint_reached)
	Events.runner_landed_on_hologram.connect(func(_h): rescues += 1)
	Events.rescue_scored.connect(func(tier: int, _at: Vector2) -> void:
		rescue_tiers[clampi(tier, 0, 3)] += 1)
	Events.enemy_killed.connect(_on_enemy_killed)

func _process(delta: float) -> void:
	if running:
		elapsed += delta

## Returns true the first time, false every time after. The whole defence
## against a resend or a reconnect paying out twice is this one answer.
func take_crystal(id: int) -> bool:
	if id < 0 or crystals_taken.has(id):
		return false
	crystals_taken[id] = true
	return true

## The taken set as a bitmask, for the handshake. Thirty-two is far more than
## any stage will hold and it is four bytes.
func crystal_mask() -> int:
	var mask := 0
	for id in crystals_taken:
		if int(id) < 32:
			mask |= 1 << int(id)
	return mask

func apply_crystal_mask(mask: int) -> void:
	crystals_taken.clear()
	for id in range(32):
		if mask & (1 << id):
			crystals_taken[id] = true

## Whether the runner holds this stage's goal key (side-scrolling stages).
var has_key: bool = false

func reset_run(start_position: Vector2) -> void:
	has_key = false
	checkpoint_index = 0
	stage_start_position = start_position
	checkpoint_position = start_position
	deaths = 0
	crystals_taken.clear()
	rescues = 0
	rescue_tiers = [0, 0, 0, 0]
	enemies_sniped = 0
	enemies_stomped = 0
	shots_blocked = 0
	boss_hp = -1
	elapsed = 0.0
	running = true

func respawn_position() -> Vector2:
	return checkpoint_position if checkpoint_index > 0 else stage_start_position

## The best grade earned this run. One sentence beats three counters: "you
## caught them four times" says less than "one of those was PERFECT".
func best_catch() -> String:
	for tier in range(3, 0, -1):
		if rescue_tiers[tier] > 0:
			return "%s x%d" % [Balance.RESCUE_NAMES[tier], rescue_tiers[tier]]
	return "-"

func stats() -> Dictionary:
	return {
		"time": elapsed,
		"deaths": deaths,
		"rescues": rescues,
		"best_catch": best_catch(),
		"sniped": enemies_sniped,
		"stomped": enemies_stomped,
		"blocked": shots_blocked,
	}

func _on_runner_died(_cause: String) -> void:
	deaths += 1

func _on_checkpoint_reached(index: int) -> void:
	if index > checkpoint_index:
		checkpoint_index = index

func _on_enemy_killed(_enemy: Node2D, by: String) -> void:
	match by:
		"snipe": enemies_sniped += 1
		"stomp": enemies_stomped += 1
