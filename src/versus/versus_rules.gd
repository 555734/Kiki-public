class_name VersusRules
## Every number the 1-1 coin match has.
##
## Separate from Balance for the same reason ArenaRules is: tuning a match must
## never move a cooperative value, and eight stages of measured arcs rest on
## Balance. Movement is NOT restated here -- the runners are the game's own
## Runner, so they already have the game's run and jump, which is the whole
## point of playing on 1-1 instead of in a box.

## Coins currently attributed to a team. First to this wins.
const WIN_AT: int = 10

## The pool of coin IDs. Bigger than WIN_AT on purpose: ten has to be reachable
## while the other team is also holding some and some are still loose, and a
## supply of exactly ten would make the last coin a coin-flip.
const COIN_TOTAL: int = 18
## How many are loose in the world at once. The spawner tops up to this.
const ON_FIELD: int = 3
## Between one coin being taken and the next appearing.
const SPAWN_GAP_TICKS: int = 45

## Nobody may take a coin for this long after it appears, or after it is
## dropped; the fighter who just lost it waits longer. Straight from the arena
## rules -- these were the numbers that stopped a held attack button from
## farming the same coin back.
const PICKUP_LOCKOUT_TICKS: int = ArenaRules.PICKUP_LOCKOUT_TICKS
const DROP_LOCKOUT_TICKS: int = ArenaRules.DROP_LOCKOUT_TICKS
const DROP_OWNER_LOCKOUT_TICKS: int = ArenaRules.DROP_OWNER_LOCKOUT_TICKS

## Distance from a coin's centre to a runner's body.
const PICKUP_RADIUS: float = 20.0

## The strike. Same 8/4/14 shape as the arena's, because it was chosen to be
## readable rather than to be fast: eight frames is enough warning to answer.
const STRIKE_STARTUP_TICKS: int = ArenaRules.ATTACK_STARTUP_TICKS
const STRIKE_ACTIVE_TICKS: int = ArenaRules.ATTACK_ACTIVE_TICKS
const STRIKE_RECOVERY_TICKS: int = ArenaRules.ATTACK_RECOVERY_TICKS

## Reach, from the runner's centre, in the direction they are facing.
const STRIKE_REACH: float = 40.0
const STRIKE_SIZE := Vector2(58.0, 48.0)

## How long a runner is out for, and where they are safe on the way back.
const RESPAWN_TICKS: int = 72

## A coin nobody takes goes back into circulation rather than sitting in a
## corner of the map for the rest of the match.
const STALE_TICKS: int = 600
const RECYCLE_TICKS: int = 45
