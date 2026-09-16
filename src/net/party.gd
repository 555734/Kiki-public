class_name Party
extends RefCounted
## Who is in this game, and the three different questions that "who" can mean.
##
## Today there are two people on one side and the three answers always line up,
## which is exactly why they are easy to conflate -- and code that conflates
## them reads fine until the day a third person arrives. Chapter 10 of the brief
## asks for team play later; this is the part of it that is worth building now,
## and the part that is not (a lobby, a server that holds a hundred people, a
## spectator mode) is deliberately absent.
##
## The three:
##
##   player_id  WHICH DEVICE. Survives a restart, survives a reconnect, and does
##              not change when the person changes seat. NetLink.client_id().
##   role       WHAT THEY DO this run -- runner or guardian. A pair can swap
##              roles between runs without becoming different people.
##   team       WHO THEY WIN WITH. Both seats share one team in co-op, and that
##              is the whole of it for now; the field exists so that "is this
##              mine" never has to be answered with "is this the runner".
##
## None of the three is derived from another. In particular none of them is the
## TRANSPORT role: whether this device is the authority is Clock.is_host, a fact
## about the netcode, and a guardian's device is not less of a player for it.

const ROLE_RUNNER := "runner"
const ROLE_GUARDIAN := "guardian"

## The one team in a co-op run. Named rather than numbered so that a log saying
## team "a" is readable, and so that the first two-team stage does not have to
## decide whether the existing side was 0 or 1.
const TEAM_A := "a"
const TEAM_B := "b"

## seat -> {"player_id": String, "role": String, "team": String}
var _seats: Dictionary = {}

## Puts a person in the game. Called once per device at the handshake, and again
## on a reconnect with the SAME player_id, which is how a returning player gets
## their seat back rather than whatever is free.
func seat(player_id: String, role: String, team: String = TEAM_A) -> void:
	if player_id.is_empty():
		return
	_seats[player_id] = {"player_id": player_id, "role": role, "team": team}

func forget(player_id: String) -> void:
	_seats.erase(player_id)

func clear() -> void:
	_seats.clear()

func knows(player_id: String) -> bool:
	return _seats.has(player_id)

func role_of(player_id: String) -> String:
	return String(_seats.get(player_id, {}).get("role", ""))

func team_of(player_id: String) -> String:
	return String(_seats.get(player_id, {}).get("team", ""))

## Everybody on a team, in no particular order.
func members(team: String) -> Array[String]:
	var out: Array[String] = []
	for id in _seats:
		if String(_seats[id].get("team", "")) == team:
			out.append(String(id))
	return out

## Are these two on the same side? The question friendly fire will ask, and the
## reason team is a field rather than a comment.
func allied(a: String, b: String) -> bool:
	if not knows(a) or not knows(b):
		return false
	return team_of(a) == team_of(b)

## Whoever is playing this role, or "" if nobody is. Two people may share a team
## but never a role, so this is single-valued by construction.
func holder_of(role: String) -> String:
	for id in _seats:
		if String(_seats[id].get("role", "")) == role:
			return String(id)
	return ""

func size() -> int:
	return _seats.size()

## For the diagnostic. Deliberately prints all three, because a report that says
## only "guest" is the report that could not explain why a reconnecting player
## came back as the wrong person.
func describe() -> String:
	var lines: Array[String] = []
	for id in _seats:
		var s: Dictionary = _seats[id]
		lines.append("  %s  役割 %s  チーム %s" % [id, s.get("role", "?"), s.get("team", "?")])
	return "\n".join(lines)
