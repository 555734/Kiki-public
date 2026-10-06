class_name VersusRoster
extends RefCounted
## Who is sitting where: four seats, two teams, two roles.
##
## Kept apart from `Party` on purpose. docs/coin-battle-plan.md:249-251 is
## explicit about why: Party's `holder_of(role)` returns ONE person overall,
## which is single-valued by construction and correct for a mode with one
## runner. This mode has two, and quietly widening Party would change the
## meaning of a function the cooperative handshake depends on.
##
## Four names, deliberately not collapsed into one number
## (docs/coin-battle-plan.md, the identity contract):
##
##   peer_id  -- which machine, assigned by the transport
##   seat     -- which chair at this table, 0..3, assigned by the host
##   team     -- which side, derived from the seat
##   role     -- runner or guardian, derived from the seat
##
## A peer that drops and comes back gets a new peer_id and the SAME seat, which
## is the whole reason they are different numbers.

enum Role { RUNNER, GUARDIAN }
## TEAM_SPLIT: 2v2, a runner and a guardian per team, one person per chair.
## DUEL_COMBINED: 1v1, each person holds their team's two chairs.
## FREE_FOR_ALL: every person is one character -- runner and builder at once --
## on a side of their own, two to eight of them.
enum RoomMode { TEAM_SPLIT, DUEL_COMBINED, FREE_FOR_ALL }

var room_mode: int = RoomMode.TEAM_SPLIT

const SEATS: int = 4
## Chairs in a free-for-all room. Also the most sides any match has.
const FFA_SEATS: int = 8
const SEAT_A_RUNNER: int = 0
const SEAT_A_GUARDIAN: int = 1
const SEAT_B_RUNNER: int = 2
const SEAT_B_GUARDIAN: int = 3

## seat -> peer_id, or -1 while empty.
var occupants: Array[int] = []

func _init(selected_mode: int = RoomMode.TEAM_SPLIT) -> void:
	room_mode = selected_mode
	for i in range(seat_count()):
		occupants.append(-1)

# ------------------------------------------------ mode-aware seat questions
## The static team_of/role_of/runner_seat below are the 4-chair answers the
## team and duel modes were built on, and stay exactly that. These ask the
## same questions of THIS room, whatever its mode.
static func seats_for(mode: int) -> int:
	return FFA_SEATS if mode == RoomMode.FREE_FOR_ALL else SEATS

static func sides_for(mode: int) -> int:
	return FFA_SEATS if mode == RoomMode.FREE_FOR_ALL else 2

static func side_of_in(mode: int, seat: int) -> int:
	return seat if mode == RoomMode.FREE_FOR_ALL else team_of(seat)

static func is_runner_in(mode: int, seat: int) -> bool:
	return mode == RoomMode.FREE_FOR_ALL or role_of(seat) == Role.RUNNER

static func runner_seat_in(mode: int, side: int) -> int:
	return side if mode == RoomMode.FREE_FOR_ALL else runner_seat(side)

## The seat a person's build commands carry. In a free-for-all it is their own
## chair; in a duel it is their team's guardian chair; in a team room only a
## guardian builds, from their own.
static func build_seat_in(mode: int, seat: int) -> int:
	if mode == RoomMode.DUEL_COMBINED and role_of(seat) == Role.RUNNER:
		return seat + 1
	return seat

static func can_build_in(mode: int, seat: int) -> bool:
	return mode == RoomMode.FREE_FOR_ALL or role_of(seat) == Role.GUARDIAN

func seat_count() -> int:
	return seats_for(room_mode)

func side_count() -> int:
	return sides_for(room_mode)

func side_of(seat: int) -> int:
	return side_of_in(room_mode, seat)

func is_runner(seat: int) -> bool:
	return is_runner_in(room_mode, seat)

func side_runner_seat(side: int) -> int:
	return runner_seat_in(room_mode, side)

func can_build(seat: int) -> bool:
	return can_build_in(room_mode, seat)

static func team_of(seat: int) -> int:
	return 0 if seat < 2 else 1

static func role_of(seat: int) -> int:
	return Role.RUNNER if seat % 2 == 0 else Role.GUARDIAN

## The seat index of a team's runner. The two runners are seats 0 and 2, and
## VersusMatch indexes its two sides by TEAM -- so this is the conversion, in
## one place, rather than a `seat / 2` scattered through the host.
static func runner_seat(team: int) -> int:
	return SEAT_A_RUNNER if team == 0 else SEAT_B_RUNNER

static func seat_name(seat: int) -> String:
	var side := "A" if team_of(seat) == 0 else "B"
	return "%s %s" % [side, "runner" if role_of(seat) == Role.RUNNER else "guardian"]

## Sit a peer down. Returns the seat, or -1 when the table is full.
##
## A peer already seated keeps its chair: this is what a reconnect looks like
## from here, and re-seating them somewhere else would swap two players'
## characters mid-match.
func seat_peer(peer_id: int, wanted: int = -1) -> int:
	var already := seat_of(peer_id)
	if already >= 0:
		return already
	if room_mode == RoomMode.FREE_FOR_ALL:
		# Nobody picks a chair: the host has 0, and everyone else gets the
		# lowest free one. A full room says so.
		if wanted == 0 and occupants[0] == -1:
			occupants[0] = peer_id
			return 0
		for i in range(1, seat_count()):
			if occupants[i] == -1:
				occupants[i] = peer_id
				return i
		return -1
	if room_mode == RoomMode.DUEL_COMBINED:
		if wanted != SEAT_A_RUNNER and wanted != SEAT_B_RUNNER:
			return -1
		if occupants[wanted] != -1 or occupants[wanted + 1] != -1:
			return -1
		occupants[wanted] = peer_id
		occupants[wanted + 1] = peer_id
		return wanted
	# A requested chair is authoritative; never silently assign a different
	# actor after the client created its local Runner/Guardian.
	if wanted >= 0 and wanted < seat_count() and occupants[wanted] != -1:
		return -1
	if wanted >= 0 and wanted < seat_count() and occupants[wanted] == -1:
		occupants[wanted] = peer_id
		return wanted
	if wanted >= 0:
		return -1
	for i in range(seat_count()):
		if occupants[i] == -1:
			occupants[i] = peer_id
			return i
	return -1

func seat_of(peer_id: int) -> int:
	for i in range(seat_count()):
		if occupants[i] == peer_id:
			return i
	return -1

func owns_seat(peer_id: int, seat: int) -> bool:
	return seat >= 0 and seat < seat_count() and occupants[seat] == peer_id

func peer_at(seat: int) -> int:
	return occupants[seat] if seat >= 0 and seat < seat_count() else -1

## The same person on a new connection: every chair `old_peer` holds is now
## `new_peer`'s. Returns the (first) seat, or -1 if `old_peer` held none.
func rebind(old_peer: int, new_peer: int) -> int:
	var seat := seat_of(old_peer)
	if seat < 0 or old_peer == new_peer:
		return seat
	# Whatever chair the new connection had already been given goes back.
	vacate(new_peer)
	for i in range(seat_count()):
		if occupants[i] == old_peer:
			occupants[i] = new_peer
	return seat

func vacate(peer_id: int) -> int:
	var seat := seat_of(peer_id)
	for i in range(seat_count()):
		if occupants[i] == peer_id:
			occupants[i] = -1
	return seat

func peers_filled() -> int:
	var found: Dictionary = {}
	for p in occupants:
		if p >= 0:
			found[p] = true
	return found.size()

func filled() -> int:
	var n := 0
	for o in occupants:
		if o != -1:
			n += 1
	return n

func is_full() -> bool:
	return filled() == seat_count()

## Both runners have to be present for a match to mean anything; a missing
## guardian is a team playing without their builder, which is a handicap rather
## than a broken match.
##
## A free-for-all needs two people, whoever they are.
func can_play() -> bool:
	if room_mode == RoomMode.FREE_FOR_ALL:
		return peers_filled() >= 2
	return peer_at(SEAT_A_RUNNER) != -1 and peer_at(SEAT_B_RUNNER) != -1

func describe() -> String:
	var parts: Array[String] = []
	for i in range(seat_count()):
		parts.append("%s=%s" % [seat_name(i) if room_mode != RoomMode.FREE_FOR_ALL
			else "P%d" % (i + 1),
			"-" if occupants[i] == -1 else str(occupants[i])])
	return ", ".join(parts)
