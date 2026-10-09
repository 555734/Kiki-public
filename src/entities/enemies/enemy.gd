class_name Enemy
extends CharacterBody2D
## Base for the three enemy types the MVP calls for (chapter 8: walker, flyer,
## turret). They exist to give the guardian something to read a few seconds
## ahead of the runner -- chapter 9 lists "the god player has nothing to do" as
## a failure mode, so every enemy is placed to create one decision.

const LAYER_ENEMY := 4

## A name of this enemy's own, fixed when the stage is built and the same on
## both devices.
##
## Enemies used to be identified over the wire by their POSITION in
## get_nodes_in_group("enemy"), and that list gets shorter every time one dies.
## So the first kill shifted every later enemy's id by one, and from then on the
## guardian's device moved each enemy to a different enemy's place -- a walker
## onto a flyer's height, hanging in the air over the grass. Both of the things
## that were reported, "they float" and "the dead one just stands there", came
## out of this one line.
var net_id: int = -1

@export var hp: int = 1
var spawn_position: Vector2 = Vector2.ZERO
var visual: Node2D = null

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = LAYER_ENEMY
	collision_mask = 1 | 8   # terrain | hologram
	spawn_position = global_position
	_build_body()
	if is_flickable():
		add_to_group("flickable")
	if is_swipeable():
		add_to_group("swipeable")

func _build_body() -> void:
	pass

# ---------------------------------------------------------------- the hand
# What the guardian's finger can do to this enemy (GuardianHand). Most enemies
# are neither: they are the rifle's. Each type that is says so here.

## Big enough to take hold of: a finger that lands on it and leaves fast throws
## it off the screen.
func is_flickable() -> bool:
	return false

## Small and in the air: a quick swipe of the hand sweeps it away.
func is_swipeable() -> bool:
	return false

## How far from its middle a finger may land and still have it.
func hand_radius() -> float:
	return Balance.HAND_GRAB_ENEMY

## Flicked away by the guardian's finger, `direction` the way the finger went.
## HOST only, like every other judgement about the world.
func flick(direction: Vector2) -> void:
	if hp <= 0 or is_queued_for_deletion():
		return
	Events.enemy_flicked.emit(global_position, direction)
	# It is already beaten, but it leaves by flying, not by vanishing: harmless,
	# spinning off the screen for a moment, and only then gone. The other
	# device watches it go in the snapshots, like any enemy moving.
	hp = 0
	collision_layer = 0
	collision_mask = 0
	remove_from_group("flickable")
	remove_from_group("swipeable")
	set_physics_process(false)
	var flight := FlickFlight.new()
	flight.velocity = direction.normalized() * 1500.0
	add_child(flight)

## Carries a flicked enemy off the screen, then removes it.
class FlickFlight extends Node:
	var velocity := Vector2.ZERO
	var _t := 0.0
	const LIFE := 0.7

	func _physics_process(delta: float) -> void:
		var body := get_parent() as Enemy
		if body == null:
			return
		_t += delta
		velocity.y += 500.0 * delta
		body.global_position += velocity * delta
		body.rotation += 14.0 * signf(velocity.x if absf(velocity.x) > 1.0 else 1.0) * delta
		body.scale = Vector2.ONE * lerpf(1.0, 0.4, clampf(_t / LIFE, 0.0, 1.0))
		if _t >= LIFE and not body.is_queued_for_deletion():
			body.die("flick")

## Swept out of the air by a swipe. HOST only.
func sweep() -> void:
	if hp <= 0 or is_queued_for_deletion():
		return
	hp = 0
	die("swipe")

func take_damage(amount: int, by: String = "snipe") -> void:
	# Already dying. Two hits can land on the same frame -- a shot and a stomp,
	# or two shots at a target with several shootable parts -- and the node is
	# not actually gone until the frame ends, so the second one would walk into
	# a freed object. die() would also fire enemy_killed twice, which on the
	# wire is two ENEMY_DIE packets for one enemy.
	if hp <= 0 or is_queued_for_deletion():
		return
	hp -= amount
	if hp <= 0:
		die(by)

func die(by: String) -> void:
	Events.enemy_killed.emit(self, by)
	queue_free()

## Shared helper: a rectangular collider of the given size.
func _add_box(size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	add_child(shape)
