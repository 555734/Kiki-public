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
## How many are loose in the world at once: exactly one. Everybody is after
## the same star, and a new one appears only once it has been taken.
const ON_FIELD: int = 1
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
## Matched to the star's drawn size (44px radius): a star you are visibly
## touching is a star you take.
const PICKUP_RADIUS: float = 48.0

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

# ------------------------------------------------------------ free-for-all
## みんなで: every person one character, everyone against everyone, two to
## eight of them. The first PERSON holding this many wins.
const FFA_WIN_AT: int = 7
## More stars in the pool than 2v2: with eight hands holding some, seven has
## to stay reachable for one of them.
const FFA_COIN_TOTAL: int = 20
## One loose star whatever the head count, as in 2v2.
static func ffa_on_field(_players: int) -> int:
	return 1

## The numbers a match is set up with, for a mode and a head count.
static func numbers_for(room_mode: int, players: int) -> Dictionary:
	if room_mode == VersusRoster.RoomMode.FREE_FOR_ALL:
		return {"win_at": FFA_WIN_AT, "coin_total": FFA_COIN_TOTAL,
			"on_field": ffa_on_field(players)}
	return {"win_at": WIN_AT, "coin_total": COIN_TOTAL, "on_field": ON_FIELD}

## One colour per chair in a free-for-all. Picked to stay apart from each
## other and from 1-1's green and sky: blue, orange, pink, yellow, violet,
## teal, red, white.
const PLAYER_COLOURS: Array = [
	Color(0.30, 0.74, 1.0), Color(1.0, 0.55, 0.26), Color(1.0, 0.45, 0.78),
	Color(1.0, 0.88, 0.25), Color(0.66, 0.50, 1.0), Color(0.25, 0.88, 0.72),
	Color(0.95, 0.25, 0.28), Color(0.94, 0.95, 0.98),
]

## A side's colour in this mode: a team's in 2v2 and 1v1, a person's here.
static func colour_of(room_mode: int, side: int) -> Color:
	if room_mode == VersusRoster.RoomMode.FREE_FOR_ALL:
		return PLAYER_COLOURS[clampi(side, 0, PLAYER_COLOURS.size() - 1)]
	return ArenaRules.TEAM_COLOURS[clampi(side, 0, 1)]

# ---------------------------------------------------------------- attacks
## Shooting is the co-op rifle (SniperAbility) on each player's own device;
## what reaches the host is "I hit whoever is at this point", checked against
## where the host has everybody, within this distance.
const SHOT_ASSIST_RADIUS: float = 110.0
## The co-op rifle has no cooldown: the gauge is the limit. Kept at a few
## ticks only so a report repeated by the network cannot double a hit.
const SHOT_COOLDOWN_TICKS: int = 3
## Stomping: landing on a head at least this fast (px/s, downwards).
const STOMP_MIN_FALL: float = 60.0
## The bounce a stomp gives the stomper, as a jump velocity.
const STOMP_BOUNCE: float = -620.0
## A hit runner is untouchable for this long.
const HIT_IMMUNE_TICKS: int = 60
## Bumping: two runners within this many px of touching, side by side, both
## drop a star and are knocked apart this hard. The reach is more than "a
## few pixels" because each machine stops against where it last saw the other
## body, and the host compares two such reports.
const BUMP_REACH: float = 12.0
const BUMP_KNOCK := Vector2(420.0, -200.0)
