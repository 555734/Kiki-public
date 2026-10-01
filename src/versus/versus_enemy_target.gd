extends Area2D
## What the co-op rifle finds on an enemy (sniper_ability.gd looks for
## take_damage on the shootable layer). Only an enemy that is up, in a match
## that is on, and in the open -- a shot comes down from above, so one under a
## platform or a row is safe -- is a target; the hit goes to the host.

var enemy = null

func is_shootable_now() -> bool:
	if enemy == null or not enemy.is_up() or enemy.arena == null:
		return false
	var arena = enemy.arena
	if arena.waiting() or arena.countdown_ticks() > 0 \
			or arena.phase() != VersusMatch.Phase.PLAYING:
		return false
	var at: Vector2 = enemy.global_position
	return arena.line_clear(at + VersusRules.SHOT_FROM, at)

func take_damage(_amount: int = 1, _source: String = "") -> void:
	if enemy != null and enemy.arena != null:
		enemy.arena.report_enemy_hit(enemy.id)
