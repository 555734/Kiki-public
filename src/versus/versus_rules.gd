class_name VersusRules
## Every number the 2v2 star match has.
##
## The ledger underneath is the coin ledger (ArenaCoin) unchanged; what the
## players see and collect is a star. The code keeps the "coin" names so the
## ledger, the wire format and the probes keep one vocabulary.
##
## Separate from Balance for the same reason ArenaRules is: tuning a match must
## never move a cooperative value, and eight stages of measured arcs rest on
## Balance. Movement is NOT restated here -- the runners are the game's own
## Runner, so they already have the game's run and jump, which is the whole
## point of playing on 1-1 instead of in a box.

## Stars currently held by a team. First to this wins. HELD, not collected:
## a hit knocks one loose and a fall returns them all, so seven has to be kept
## as well as taken.
const WIN_AT: int = 7

## The pool of star IDs. Bigger than WIN_AT on purpose: seven has to be reachable
## while the other team is also holding some and some are still loose, and a
## supply of exactly seven would make the last star a coin-flip.
const COIN_TOTAL: int = 12
## How many are loose in the world at once. The spawner tops up to this. Two on
## a three-screen field: enough that both teams have one to go for, few enough
## that each one is contested.
const ON_FIELD: int = 2
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

## "3, 2, 1" before a match (and a rematch) starts, once the host presses
## start. Everyone is frozen at their start for it, so the player whose device
## connected first gets no head start.
const COUNTDOWN_TICKS: int = 180

## The arena is about three screens wide. Pulled back a little from the
## cooperative 1.5 so more of it -- and more of the other team -- is on screen.
const CAMERA_ZOOM: float = 1.2

## A coin nobody takes goes back into circulation rather than sitting in a
## corner of the map for the rest of the match.
const STALE_TICKS: int = 600
const RECYCLE_TICKS: int = 45
