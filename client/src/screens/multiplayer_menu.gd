class_name MultiplayerMenu
extends Control

## Multiplayer lobby: CREATE MATCH / JOIN MATCH with 6-digit code entry,
## connection status, and waiting state.

signal back()
signal match_begin(payload: Dictionary)

var status_label: Label
var code_entry: LineEdit
var room_code_label: Label
var create_panel: Control
var join_panel: Control
var waiting_panel: Control
var conn_status: Label
var _net_connections: Array = []

func _ready() -> void:
	add_child(UITheme.make_background())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 24)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root)

	root.add_child(UITheme.make_label("MULTIPLAYER", 52, GameConfig.COLOR_TEXT))
	conn_status = UITheme.make_label("Connecting…", 22, GameConfig.COLOR_TEXT_DIM)
	root.add_child(conn_status)

	status_label = UITheme.make_label("", 22, Color("ff5a6e"))
	root.add_child(status_label)

	# ---- create panel ----
	create_panel = PanelContainer.new()
	create_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(1, 1, 1, 0.05), 20))
	create_panel.custom_minimum_size = Vector2(560, 0)
	create_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(create_panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	create_panel.add_child(cv)
	cv.add_child(UITheme.make_label("CREATE MATCH", 28, GameConfig.COLOR_ACCENT_2))
	room_code_label = UITheme.make_label("", 72, GameConfig.COLOR_GOLD)
	cv.add_child(room_code_label)
	var create_btn := UITheme.make_button("CREATE ROOM", GameConfig.COLOR_ACCENT, 28)
	create_btn.pressed.connect(func(): AudioMan.tap(); Net.create_room())
	cv.add_child(create_btn)

	# ---- join panel ----
	join_panel = PanelContainer.new()
	join_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color(1, 1, 1, 0.05), 20))
	join_panel.custom_minimum_size = Vector2(560, 0)
	join_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(join_panel)
	var jv := VBoxContainer.new()
	jv.add_theme_constant_override("separation", 14)
	join_panel.add_child(jv)
	jv.add_child(UITheme.make_label("JOIN MATCH", 28, GameConfig.COLOR_ACCENT_2))
	code_entry = LineEdit.new()
	code_entry.placeholder_text = "6-digit room code"
	code_entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_entry.max_length = 6
	code_entry.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	code_entry.add_theme_font_size_override("font_size", 40)
	code_entry.custom_minimum_size = Vector2(0, 90)
	code_entry.add_theme_stylebox_override("normal", UITheme.panel_style(Color(0, 0, 0, 0.3), 14, GameConfig.COLOR_CELL_EDGE, 2, false))
	jv.add_child(code_entry)
	var join_btn := UITheme.make_button("JOIN ROOM", Color("25b3a0"), 28)
	join_btn.pressed.connect(_on_join)
	jv.add_child(join_btn)

	# ---- waiting indicator ----
	waiting_panel = VBoxContainer.new()
	waiting_panel.add_theme_constant_override("separation", 10)
	waiting_panel.visible = false
	root.add_child(waiting_panel)
	waiting_panel.add_child(UITheme.make_label("Waiting for opponent…", 26, GameConfig.COLOR_TEXT_DIM))

	var back_btn := UITheme.make_button("BACK", Color("3a3f6e"), 26)
	back_btn.custom_minimum_size = Vector2(280, 64)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.pressed.connect(func(): AudioMan.tap(); Net.leave_room(); back.emit())
	root.add_child(back_btn)

	_bind(Net.connection_changed, _on_conn_changed)
	_bind(Net.room_created, _on_room_created)
	_bind(Net.room_joined, _on_room_joined)
	_bind(Net.player_joined, _on_player_joined)
	_bind(Net.match_started, _on_match_started)
	_bind(Net.server_error, _on_server_error)
	tree_exiting.connect(_unbind_all)

	Net.player_id = Settings.player_id
	Net.display_name = Settings.display_name
	Net.token = Settings.session_token
	Net.open()
	_on_conn_changed(Net.net.is_open())

func _bind(sig: Signal, fn: Callable) -> void:
	sig.connect(fn)
	_net_connections.append([sig, fn])

func _unbind_all() -> void:
	for pair in _net_connections:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	_net_connections.clear()

func _on_conn_changed(connected: bool) -> void:
	conn_status.text = "Connected to server" if connected else "Connecting…"
	conn_status.add_theme_color_override("font_color",
		Color("3ddc84") if connected else GameConfig.COLOR_TEXT_DIM)

func _on_room_created(code: String) -> void:
	room_code_label.text = code
	status_label.text = ""
	waiting_panel.visible = true
	join_panel.visible = false
	_show_room_code_flash()

func _show_room_code_flash() -> void:
	room_code_label.pivot_offset = room_code_label.size * 0.5
	var tw := room_code_label.create_tween().set_loops()
	tw.tween_property(room_code_label, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(room_code_label, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)

func _on_room_joined(players: Array) -> void:
	status_label.text = ""
	waiting_panel.visible = true
	create_panel.visible = false

func _on_player_joined(players: Array) -> void:
	waiting_panel.visible = true
	var names: Array = []
	for p in players:
		names.append(str(p.get("name", "?")))
	status_label.text = "%s  vs  %s" % [names[0] if names.size() > 0 else "?", names[1] if names.size() > 1 else "?"]
	status_label.add_theme_color_override("font_color", Color("3ddc84"))

func _on_match_started(payload: Dictionary) -> void:
	match_begin.emit(payload)

func _on_join() -> void:
	var code := code_entry.text.strip_edges()
	if code.length() != 6:
		status_label.text = "Enter the 6-digit code."
		AudioMan.invalid()
		return
	AudioMan.tap()
	Net.join_room(code)

func _on_server_error(code: String, message: String) -> void:
	match code:
		"room_not_found": status_label.text = "No room with that code."
		"join_failed", "bad_code": status_label.text = message
		_: status_label.text = message
	AudioMan.invalid()
