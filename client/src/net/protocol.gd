class_name Protocol
extends RefCounted

## Wire protocol constants — mirrors server/src/protocol.ts.
## Messages are JSON: {"type": <str>, "payload": <dict>}.

# client -> server
const CONNECT := "CONNECT"
const CREATE_ROOM := "CREATE_ROOM"
const JOIN_ROOM := "JOIN_ROOM"
const LEAVE_ROOM := "LEAVE_ROOM"
const PLACE_PIECE := "PLACE_PIECE"
const GAME_OVER := "GAME_OVER"
const REMATCH := "REMATCH"
const PING := "PING"

# server -> client
const CONNECTED := "CONNECTED"
const ROOM_CREATED := "ROOM_CREATED"
const ROOM_JOINED := "ROOM_JOINED"
const PLAYER_JOINED := "PLAYER_JOINED"
const PLAYER_LEFT := "PLAYER_LEFT"
const START_MATCH := "START_MATCH"
const PLACE_ACCEPTED := "PLACE_ACCEPTED"
const PLACE_REJECTED := "PLACE_REJECTED"
const BOARD_UPDATE := "BOARD_UPDATE"
const SCORE_UPDATE := "SCORE_UPDATE"
const COMBO_UPDATE := "COMBO_UPDATE"
const OPPONENT_GAME_OVER := "OPPONENT_GAME_OVER"
const OPPONENT_DISCONNECTED := "OPPONENT_DISCONNECTED"
const OPPONENT_RECONNECTED := "OPPONENT_RECONNECTED"
const RECONNECT_STATE := "RECONNECT_STATE"
const TICK := "TICK"
const MATCH_END := "MATCH_END"
const REMATCH_STATUS := "REMATCH_STATUS"
const PONG := "PONG"
const ERROR := "ERROR"

static func encode(type: String, payload: Dictionary = {}) -> String:
	return JSON.stringify({"type": type, "payload": payload})

## Returns Dictionary {type, payload} or empty dict when malformed.
static func decode(raw: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var t: Variant = parsed.get("type")
	if typeof(t) != TYPE_STRING:
		return {}
	var payload: Variant = parsed.get("payload", {})
	if typeof(payload) != TYPE_DICTIONARY:
		payload = {}
	return {"type": t, "payload": payload}
