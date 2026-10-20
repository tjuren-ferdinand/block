class_name DebugPanel
extends PanelContainer

## Developer overlay: connection state, ids, seed, ping, last message.
## Hidden unless enabled in Settings or triple-tapping the menu title.

var _labels := {}
var _last_msg := "-"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(12, 120)
	custom_minimum_size = Vector2(430, 0)
	add_theme_stylebox_override("panel", UITheme.panel_style(Color(0, 0, 0, 0.72), 12, Color.TRANSPARENT, 0, false))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	add_child(vb)
	vb.add_child(UITheme.make_label("DEBUG", 20, Color("4de3c2"), false))
	for key in ["server", "ws", "ping", "room", "player", "match", "seed", "lastmsg"]:
		var l := UITheme.make_label("%s: -" % key, 18, Color(1, 1, 1, 0.8), false)
		l.name = key
		vb.add_child(l)
		_labels[key] = l
	Net.net.message.connect(_on_msg)
	visible = Settings.debug_enabled

func _process(_delta: float) -> void:
	visible = Settings.debug_enabled
	if not visible:
		return
	_labels["server"].text = "server: %s" % GameConfig.server_url()
	_labels["ws"].text = "ws: %s" % ("OPEN" if Net.net.is_open() else "closed (state %d)" % Net.net.peer.get_ready_state() if Net.net.peer else "closed")
	_labels["ping"].text = "ping: %d ms" % Net.last_rtt_ms
	_labels["room"].text = "room: %s" % (Net.room_code if Net.room_code != "" else "-")
	_labels["player"].text = "player: %s (%s)" % [Net.player_id, Settings.display_name]
	_labels["match"].text = "match: %s" % (Net.match_id if Net.match_id != "" else "-")
	_labels["seed"].text = "seed: %d" % Net.seed
	_labels["lastmsg"].text = "last: %s" % _last_msg

func _on_msg(type: String, _payload: Dictionary) -> void:
	_last_msg = type
