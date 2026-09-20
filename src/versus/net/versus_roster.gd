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
enum RoomMode { TEAM_SPLIT, DUEL_COMBINED }

var room_mode: int = RoomMode.TEAM_SPLIT

const SEATS: int = 4
const SEAT_A_RUNNER: int = 0
const SEAT_A_GUARDIAN: int = 1
const SEAT_B_RUNNER: int = 2
const SEAT_B_GUARDIAN: int = 3

## seat -> peer_id, or -1 while empty.
var occupants: Array[int] = []

func _init(selected_mode: int = RoomMode.TEAM_SPLIT) -> void:
	room_mode = selected_mode
	for i in range(SEATS):
		occupants.append(-1)

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
	if wanted >= 0 and wanted < SEATS and occupants[wanted] != -1:
		return -1
	if wanted >= 0 and wanted < SEATS and occupants[wanted] == -1:
		occupants[wanted] = peer_id
		return wanted
	if wanted >= 0:
		return -1
	for i in range(SEATS):
		if occupants[i] == -1:
			occupants[i] = peer_id
			return i
	return -1

func seat_of(peer_id: int) -> int:
	for i in range(SEATS):
		if occupants[i] == peer_id:
			return i
	return -1

func owns_seat(peer_id: int, seat: int) -> bool:
	return seat >= 0 and seat < SEATS and occupants[seat] == peer_id

func peer_at(seat: int) -> int:
	return occupants[seat] if seat >= 0 and seat < SEATS else -1

func vacate(peer_id: int) -> int:
	var seat := seat_of(peer_id)
	for i in range(SEATS):
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
	return filled() == SEATS

## Both runners have to be present for a match to mean anything; a missing
## guardian is a team playing without their builder, which is a handicap rather
## than a broken match.
func can_play() -> bool:
	return peer_at(SEAT_A_RUNNER) != -1 and peer_at(SEAT_B_RUNNER) != -1

func describe() -> String:
	var parts: Array[String] = []
	for i in range(SEATS):
		parts.append("%s=%s" % [seat_name(i),
			"-" if occupants[i] == -1 else str(occupants[i])])
	return ", ".join(parts)
