extends Node
## Global signal bus.
##
## The two players never touch each other's nodes directly. The runner reports
## what happened to it, the guardian reports what it placed, and the HUD listens
## to both. That keeps the asymmetry honest: neither side can reach into the
## other's systems, which is also what makes adding netcode later tractable.

# --- runner -----------------------------------------------------------------
signal runner_spawned(runner: Node2D)
signal runner_damaged(hp: int, max_hp: int)
signal runner_died(cause: String)
signal runner_respawned(checkpoint_index: int)
signal runner_stomped_enemy(enemy: Node2D)
## The runner picked up a coin. Both devices raise this from their own copy of
## the runner; only the host acts on it, because the gauge is the host's.
signal coin_collected(world_position: Vector2)
## The runner has reached a crystal. Raised by the crystal on the host only; the
## host decides whether it counts and then says so with crystal_taken.
signal crystal_reached(crystal: Node2D)
## A crystal has actually been collected, with what it put back. Both devices
## see this one -- the runner needs to know the trip paid, and the guardian needs
## to know what they can now afford.
signal crystal_taken(net_id: int, world_position: Vector2, amount: float)
signal spring_bounced(world_position: Vector2)
## The guardian tapped the construct the runner was standing on and threw them
## off it. A separate signal from spring_bounced so the two can sound and look
## different -- one is the stage, the other is a person deciding.
signal runner_launched(world_position: Vector2)
## Kicked off one of the guardian's walls. Carries which way they went, because
## the dust and the sound both want it.
signal runner_wall_jumped(world_position: Vector2, away: int)
## Caught the edge of something on the way down. The guardian has about three
## seconds from here, and this is what tells them the clock has started.
signal runner_grabbed_ledge(world_position: Vector2)
signal runner_let_go(world_position: Vector2)
signal runner_landed_on_hologram(hologram: Node2D)
## Movement, for the sound and nothing else. These exist because the game had no
## voice: everything the runner does happened in silence, and on two devices the
## only channel that tells the guardian "they jumped" without taking their eyes
## off the aim point is the one they hear.
signal runner_jumped()
signal runner_landed(hard: bool)
## The guardian caught a falling runner, and how late they left it. See
## Balance.RESCUE_TIERS -- this is the one place the difference between a good
## guardian and an adequate one becomes visible.
signal rescue_scored(tier: int, world_position: Vector2)
## The guardian's warp pair moved the runner. Carries both ends so the FX
## can flash the gate they left as well as the one they arrived at.
signal runner_warped(from: Vector2, to: Vector2)

# --- guardian ---------------------------------------------------------------
signal gauge_changed(value: float, maximum: float)
signal ability_selected(slot: int)
signal ability_used(slot: int, world_position: Vector2)
signal ability_refused(slot: int, reason: String)
signal scope_state_changed(active: bool, zoom: float)
signal shot_fired(from: Vector2, to: Vector2, hit: bool)
## The shot landed on something that refused it -- a shield, or a soft spot that
## is shut. Its own signal because "refused" and "missed" feel identical
## otherwise, and only one of them means "aim at the other side".
signal shot_blocked(world_position: Vector2)
signal hologram_spawned(kind: int, world_position: Vector2)
signal hologram_expired(kind: int)
## The guardian took one back. Not the same as expiring: nothing is refunded and
## the guardian chose it, so it wants its own sound and its own packet.
signal hologram_revoked(net_id: int)

# --- world ------------------------------------------------------------------
signal enemy_killed(enemy: Node2D, by: String)

## A shield-bearer's soft spot is open until `until_tick`. Raised by the HOST
## only: whether the runner has done enough to open it is a judgement about the
## world, and two devices judging separately is two answers. See Shieldbearer.
signal weak_point_opened(enemy: Node2D, until_tick: int)
## The Keeper's state machine moved on: it is winding up, charging, reeling or
## falling. Raised on BOTH devices -- the host from its own machine, the
## guardian's from the packet that tells it what the host decided -- because the
## drawing, the sound and the bar all hang off it. See Keeper.
signal keeper_state_changed(keeper: Node2D)
## Two wounds in: the fight has moved into the next act, and the arena loses a
## pillar. HOST-decided, like every judgement about the world.
signal keeper_act_changed(act: int)
## Something very heavy hit something very solid. For the dust and the shake.
signal keeper_slammed(world_position: Vector2)
signal switch_activated(switch_id: String)
signal checkpoint_reached(index: int)
## Every enemy, gimmick and pickup in the stage has just been thrown away and
## made again -- a respawn or a restart. Anything holding a reference to one of
## them is now holding a freed object and has to look them up afresh.
signal level_rebuilt()
signal stage_cleared(stats: Dictionary)
signal countdown_started()

# --- meta -------------------------------------------------------------------
signal roles_swapped(runner_on_left: bool)
signal notice(text: String)
## Somebody pointed at somewhere. kind 1 is "here", 2 is "wait". Shown on BOTH
## screens: a mark only the person who made it can see is not communication.
signal pinged(world_position: Vector2, kind: int, from_runner: bool)
## The link's health, for the one banner that tells the players what is going
## on. "" is fine; anything else is a line to put on screen.
signal link_state(text: String)
