class_name NetClient
extends Node

## Thin WebSocketPeer wrapper. Polls in _process and surfaces JSON messages.
## No game logic lives here — MatchClient consumes the signals.

signal connected()
signal disconnected(reason: String)
signal message(type: String, payload: Dictionary)

var peer: WebSocketPeer
var url := ""
var last_rx_ms := 0
var _connect_issued := false
var _was_open := false

func connect_to(url_to_use: String) -> void:
	url = url_to_use
	peer = WebSocketPeer.new()
	peer.inbound_buffer_size = 65536
	var err := peer.connect_to_url(url)
	if err != OK:
		disconnected.emit("connect_failed")
		return
	_connect_issued = true

func send_msg(type: String, payload: Dictionary = {}) -> bool:
	if peer == null or peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	return peer.send_text(Protocol.encode(type, payload)) == OK

func is_open() -> bool:
	return peer != null and peer.get_ready_state() == WebSocketPeer.STATE_OPEN

func close_socket(code := 1000, reason := "") -> void:
	if peer != null:
		peer.close(code, reason)

func _process(_delta: float) -> void:
	if peer == null or not _connect_issued:
		return
	peer.poll()
	var state := peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			connected.emit()
		last_rx_ms = Time.get_ticks_msec()
		while peer.get_available_packet_count() > 0:
			var pkt := peer.get_packet()
			var msg := Protocol.decode(pkt.get_string_from_utf8())
			if msg.is_empty():
				continue
			last_rx_ms = Time.get_ticks_msec()
			message.emit(msg["type"], msg["payload"])
	elif state == WebSocketPeer.STATE_CLOSED:
		var reason := "closed"
		if peer.get_close_code() != -1:
			reason = "code_%d" % peer.get_close_code()
		_connect_issued = false
		_was_open = false
		disconnected.emit(reason)
