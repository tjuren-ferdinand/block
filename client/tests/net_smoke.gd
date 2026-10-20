class_name NetSmoke
extends RefCounted

## End-to-end network smoke test inside the real game (autoloads live).
## Boot with:  npm run dev   (in server/)
##             godot --path client -- --net-smoke
## The test connects the real Net autoload, creates a room, then drives a
## raw WebSocket "bot" as the opponent — verifying seed sync, validated
## placements, live opponent board updates, and match timing.

const TIMEOUT_MS := 9000

var tree: SceneTree
var main: Control
var errors := 0
var _room_code := ""
var _start_payload := {}
var _bot_start := {}

class Bot:
	var ws := WebSocketPeer.new()
	var inbox: Array = []
	var player_id := "bot-player"
	var bot_name := "Bot"

	func open(url: String) -> bool:
		return ws.connect_to_url(url) == OK

	func poll() -> void:
		ws.poll()
		while ws.get_available_packet_count() > 0:
			var txt := ws.get_packet().get_string_from_utf8()
			var m = JSON.parse_string(txt)
			if typeof(m) == TYPE_DICTIONARY:
				inbox.append(m)

	func send(type: String, payload: Dictionary = {}) -> void:
		ws.send_text(JSON.stringify({"type": type, "payload": payload}))

	func take(type: String) -> Dictionary:
		for i in inbox.size():
			if inbox[i].get("type") == type:
				var m = inbox[i]
				inbox.remove_at(i)
				return m
		return {}

	func connected() -> bool:
		return ws.get_ready_state() == WebSocketPeer.STATE_OPEN

func run(p_tree: SceneTree, p_main: Control) -> int:
	tree = p_tree
	main = p_main
	var url := GameConfig.server_url()
	print("NET SMOKE vs %s" % url)

	Net.player_id = "smoke-" + str(randi() % 100000)
	Net.display_name = "SmokeBot"
	Net.token = ""
	Net.open()

	if not await _wait(func(): return Net.state == MatchClient.State.CONNECTED, "connect"):
		return _fail("could not connect to server")

	Net.room_created.connect(func(c): _room_code = c, CONNECT_ONE_SHOT)
	Net.create_room()
	if not await _wait(func(): return _room_code != "", "ROOM_CREATED"):
		return _fail("no room created")
	print("room code: ", _room_code)

	var bot := Bot.new()
	if not bot.open(url):
		return _fail("bot connect failed")
	if not await _wait(func(): return bot.connected(), "bot ws open", bot):
		return _fail("bot ws not open")
	bot.send(Protocol.CONNECT, {"playerId": bot.player_id, "name": bot.bot_name})
	if not await _wait(func(): return not bot.take(Protocol.CONNECTED).is_empty(), "bot CONNECTED", bot):
		return _fail("bot no CONNECTED")
	bot.send(Protocol.JOIN_ROOM, {"roomCode": _room_code})

	Net.match_started.connect(func(p): _start_payload = p, CONNECT_ONE_SHOT)
	if not await _wait(func():
			var m: Dictionary = bot.take(Protocol.START_MATCH)
			if not m.is_empty():
				_bot_start = m
				return true
			return false, "bot START_MATCH", bot):
		return _fail("bot never got START_MATCH")
	if not await _wait(func(): return not _start_payload.is_empty(), "game START_MATCH"):
		return _fail("game never got START_MATCH")

	var seed := int(_start_payload.get("seed", -1))
	var bot_seed := int(_bot_start.get("payload", {}).get("seed", -2))
	if seed != bot_seed:
		return _fail("seed mismatch between clients")
	print("seed ok: ", seed)

	# build the real match screen (bypassing menu flow)
	main._show_match_mp(_start_payload)

	if not await _wait(func(): return not (main._current as MatchScreen)._input_blocked, "countdown", bot, 7000):
		return _fail("countdown never finished")

	var ms: MatchScreen = main._current

	# bot places piece 0 of set 0 at (0,0)
	var set0 := PieceGenerator.generate_set(seed, 0)
	var shape := BlockShapes.cells(set0[0])
	var cells: Array = []
	for off in shape:
		cells.append({"r": off.y, "c": off.x})
	bot.send(Protocol.PLACE_PIECE, {"setIndex": 0, "slotIndex": 0, "cells": cells})
	if not await _wait(func(): return not bot.take(Protocol.PLACE_ACCEPTED).is_empty(), "bot PLACE_ACCEPTED", bot):
		return _fail("bot placement not accepted")
	print("bot placement accepted")

	if not await _wait(func(): return int(ms.opp_score_label.text) > 0, "opp score update", bot):
		return _fail("opponent score never updated")
	print("opponent board visible: score=", ms.opp_score_label.text)

	# game client places its own piece; the bot must see the board update
	var anchor := Vector2i(-1, -1)
	for y in 8:
		for x in 8:
			if anchor.x < 0 and ms.controller.can_place(0, Vector2i(x, y)):
				anchor = Vector2i(x, y)
	if anchor.x < 0:
		return _fail("no legal placement for game client")
	ms._commit_placement(0, anchor)
	if not await _wait(func():
			var m: Dictionary = bot.take(Protocol.BOARD_UPDATE)
			return not m.is_empty() and str(m["payload"].get("playerId")) == Net.player_id, "bot sees my BOARD_UPDATE", bot):
		return _fail("bot never saw my board update")
	print("bot saw my board update")

	print("my score: ", ms.controller.score, " opp score: ", ms.opp_score_label.text)
	Net.leave_room()
	Net.reset_to_idle()
	if errors == 0:
		print("NET SMOKE OK — real client <-> server <-> bot round-trip verified")
	return errors

func _wait(cond: Callable, what: String, bot: Bot = null, timeout_ms := TIMEOUT_MS) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < timeout_ms:
		if bot:
			bot.poll()
		if cond.call():
			return true
		await tree.process_frame
	printerr("NET SMOKE timeout waiting for: ", what)
	return false

func _fail(msg: String) -> int:
	printerr("NET SMOKE FAIL: ", msg)
	return 1
