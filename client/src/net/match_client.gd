class_name MatchClient
extends Node

## High-level multiplayer session: CONNECT -> room -> match -> reconnect.
## Owns a NetClient and exposes game-level signals for the UI layer.
## The server is authoritative; this class only transports + tracks state.

signal connection_changed(connected: bool)
signal room_created(room_code: String)
signal room_joined(players: Array)
signal player_joined(players: Array)
signal player_left(payload: Dictionary)
signal match_started(payload: Dictionary)
signal place_accepted(payload: Dictionary)
signal place_rejected(payload: Dictionary)
signal board_sync(payload: Dictionary)          # own board correction
signal opponent_board(payload: Dictionary)      # BOARD_UPDATE for the other player
signal opponent_game_over(payload: Dictionary)
signal opponent_disconnected(payload: Dictionary)
signal opponent_reconnected(payload: Dictionary)
signal reconnect_state(payload: Dictionary)
signal tick(remaining_ms: int)
signal match_ended(payload: Dictionary)
signal rematch_status(payload: Dictionary)
signal server_error(code: String, message: String)
signal ping_updated(rtt_ms: int)

enum State { IDLE, CONNECTING, CONNECTED, IN_ROOM, PLAYING, ENDED }
var state: State = State.IDLE

var net: NetClient
var player_id := ""
var display_name := ""
var token := ""
var room_code := ""
var match_id := ""
var seed := 0
var me_in_match := false
var clock_offset_ms := 0.0   # serverNow - localNow at START_MATCH
var last_rtt_ms := 0
var reconnecting := false   # true while a live match has lost its socket
var _want_connected := false
var _ping_timer := 0.0
var _reconnect_timer := 0.0
var _ping_sent_ms := 0

func _ready() -> void:
	net = NetClient.new()
	add_child(net)
	net.connected.connect(_on_socket_connected)
	net.disconnected.connect(_on_socket_disconnected)
	net.message.connect(_on_message)

# ---- public API ----

func open() -> void:
	_want_connected = true
	if net.is_open() or state == State.CONNECTING:
		return
	state = State.CONNECTING
	connection_changed.emit(false)
	net.connect_to(GameConfig.server_url())

func create_room() -> void:
	net.send_msg(Protocol.CREATE_ROOM)

func join_room(code: String) -> void:
	net.send_msg(Protocol.JOIN_ROOM, {"roomCode": code})

func leave_room() -> void:
	net.send_msg(Protocol.LEAVE_ROOM)
	room_code = ""
	match_id = ""
	me_in_match = false
	state = State.CONNECTED

func send_placement(set_index: int, slot_index: int, cells: Array) -> void:
	var arr: Array = []
	for c in cells:
		arr.append({"r": c.y, "c": c.x})
	net.send_msg(Protocol.PLACE_PIECE, {"setIndex": set_index, "slotIndex": slot_index, "cells": arr})

func send_game_over() -> void:
	net.send_msg(Protocol.GAME_OVER)

func send_rematch() -> void:
	net.send_msg(Protocol.REMATCH)

func server_now_ms() -> float:
	return Time.get_ticks_msec() + clock_offset_ms

# ---- internals ----

func _process(delta: float) -> void:
	# heartbeat ping for RTT display
	if net.is_open():
		_ping_timer += delta
		if _ping_timer >= 2.0:
			_ping_timer = 0.0
			_ping_sent_ms = Time.get_ticks_msec()
			net.send_msg(Protocol.PING)

	# auto-reconnect: keep trying while we want a live connection
	reconnecting = me_in_match and _want_connected and not net.is_open() and state == State.PLAYING
	if _want_connected and net.peer != null and net.peer.get_ready_state() == WebSocketPeer.STATE_CLOSED and state != State.CONNECTING:
		_reconnect_timer += delta
		if _reconnect_timer >= 1.5:
			_reconnect_timer = 0.0
			state = State.CONNECTING
			net.connect_to(GameConfig.server_url())

func _on_socket_connected() -> void:
	var payload := {"playerId": player_id, "name": display_name}
	if me_in_match and not token.is_empty() and not match_id.is_empty():
		payload["token"] = token
		payload["matchId"] = match_id
	net.send_msg(Protocol.CONNECT, payload)

func _on_socket_disconnected(_reason: String) -> void:
	_reconnect_timer = 2.0 # first retry immediately
	state = State.IDLE if not me_in_match else state
	connection_changed.emit(false)

func _on_message(type: String, payload: Dictionary) -> void:
	match type:
		Protocol.CONNECTED:
			token = str(payload.get("token", ""))
			Settings.save_token(token)
			if payload.get("rejoined", false):
				reconnecting = false
				# RECONNECT_STATE follows right after
			else:
				state = State.CONNECTED
				connection_changed.emit(true)
		Protocol.ROOM_CREATED:
			room_code = str(payload.get("roomCode", ""))
			state = State.IN_ROOM
			room_created.emit(room_code)
		Protocol.ROOM_JOINED:
			room_code = str(payload.get("roomCode", ""))
			state = State.IN_ROOM
			room_joined.emit(payload.get("players", []))
		Protocol.PLAYER_JOINED:
			player_joined.emit(payload.get("players", []))
		Protocol.PLAYER_LEFT:
			player_left.emit(payload)
		Protocol.START_MATCH:
			match_id = str(payload.get("matchId", ""))
			seed = int(payload.get("seed", 0))
			me_in_match = true
			state = State.PLAYING
			var server_now := float(payload.get("serverNowMs", 0))
			clock_offset_ms = server_now - Time.get_ticks_msec()
			match_started.emit(payload)
		Protocol.PLACE_ACCEPTED:
			place_accepted.emit(payload)
		Protocol.PLACE_REJECTED:
			place_rejected.emit(payload)
		Protocol.BOARD_UPDATE:
			if str(payload.get("playerId", "")) == player_id:
				board_sync.emit(payload)
			else:
				opponent_board.emit(payload)
		Protocol.SCORE_UPDATE, Protocol.COMBO_UPDATE:
			pass # folded into PLACE_ACCEPTED / BOARD_UPDATE for the UI
		Protocol.OPPONENT_GAME_OVER:
			opponent_game_over.emit(payload)
		Protocol.OPPONENT_DISCONNECTED:
			opponent_disconnected.emit(payload)
		Protocol.OPPONENT_RECONNECTED:
			opponent_reconnected.emit(payload)
		Protocol.RECONNECT_STATE:
			reconnecting = false
			match_id = str(payload.get("matchId", match_id))
			seed = int(payload.get("seed", seed))
			me_in_match = true
			state = State.PLAYING
			connection_changed.emit(true)
			reconnect_state.emit(payload)
		Protocol.TICK:
			tick.emit(int(payload.get("remainingMs", 0)))
		Protocol.MATCH_END:
			me_in_match = false
			state = State.ENDED
			match_ended.emit(payload)
		Protocol.REMATCH_STATUS:
			rematch_status.emit(payload)
		Protocol.PONG:
			last_rtt_ms = Time.get_ticks_msec() - _ping_sent_ms
			ping_updated.emit(last_rtt_ms)
		Protocol.ERROR:
			server_error.emit(str(payload.get("code", "")), str(payload.get("message", "")))

func reset_to_idle() -> void:
	reconnecting = false
	me_in_match = false
	room_code = ""
	match_id = ""
	state = State.CONNECTED if net.is_open() else State.IDLE
