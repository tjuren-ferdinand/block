class_name ResultsScreen
extends Control

## Match result: VICTORY / DEFEAT / DRAW, both scores, stats, REMATCH + MENU.

signal rematch_accepted(payload: Dictionary)
signal exit_to_menu()

var result: Dictionary = {}
var rematch_btn: Button
var rematch_status_label: Label
var _net_connections: Array = []

func setup(p_result: Dictionary) -> void:
	result = p_result

func _ready() -> void:
	add_child(UITheme.make_background())
	var my_id := Net.player_id
	var winner: Variant = result.get("winnerId", null)
	var won := winner != null and str(winner) == my_id
	var draw := winner == null
	var title := "DRAW" if draw else ("VICTORY" if won else "DEFEAT")
	var title_color := GameConfig.COLOR_TEXT_DIM if draw else (GameConfig.COLOR_GOLD if won else Color("ff5a6e"))

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 22)
	add_child(root)

	var title_label := UITheme.make_label(title, 84, title_color)
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	title_label.add_theme_constant_override("outline_size", 10)
	root.add_child(title_label)
	title_label.pivot_offset = Vector2(200, 60)
	title_label.scale = Vector2(0.2, 0.2)
	var pop := title_label.create_tween()
	pop.tween_property(title_label, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	match (winner != null):
		true: AudioMan.win() if won else AudioMan.lose()
		false: AudioMan.draw_sfx()
	Haptics.heavy() if won else Haptics.light()

	# scores card
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.panel_style(Color(1, 1, 1, 0.05), 22))
	card.custom_minimum_size = Vector2(620, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	card.add_child(cv)

	var me := _find_player(my_id)
	var opp := _find_player(my_id, true)

	cv.add_child(_score_row("YOU", me.get("score", 0), won and not draw))
	cv.add_child(_score_row(str(opp.get("name", "OPPONENT")), opp.get("score", 0), not won and not draw))

	var sep := HSeparator.new()
	cv.add_child(sep)
	cv.add_child(UITheme.make_label("STATS", 22, GameConfig.COLOR_TEXT_DIM))
	cv.add_child(_stat_row("Lines cleared", me.get("linesCleared", 0)))
	cv.add_child(_stat_row("Blocks placed", me.get("blocksPlaced", 0)))
	cv.add_child(_stat_row("Best combo", me.get("bestCombo", 0)))

	rematch_status_label = UITheme.make_label("", 22, GameConfig.COLOR_TEXT_DIM)
	root.add_child(rematch_status_label)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 22)
	root.add_child(btns)

	rematch_btn = UITheme.make_button("REMATCH", GameConfig.COLOR_ACCENT, 30)
	rematch_btn.custom_minimum_size = Vector2(280, 84)
	rematch_btn.pressed.connect(_on_rematch)
	btns.add_child(rematch_btn)

	var menu_btn := UITheme.make_button("MAIN MENU", Color("3a3f6e"), 30)
	menu_btn.custom_minimum_size = Vector2(280, 84)
	menu_btn.pressed.connect(func():
		AudioMan.tap()
		Net.leave_room()
		Net.reset_to_idle()
		exit_to_menu.emit())
	btns.add_child(menu_btn)

	_bind(Net.rematch_status, _on_rematch_status)
	_bind(Net.match_started, func(p): rematch_accepted.emit(p))
	tree_exiting.connect(_unbind_all)

func _find_player(my_id: String, want_opp := false) -> Dictionary:
	for p in result.get("players", []):
		var is_me := str(p.get("playerId", "")) == my_id
		if is_me != want_opp:
			return p
	return {}

func _score_row(label: String, score: int, highlight: bool) -> Control:
	var h := HBoxContainer.new()
	var l := UITheme.make_label(label, 30, GameConfig.COLOR_TEXT, false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var s := UITheme.make_label(str(score), 44, GameConfig.COLOR_GOLD if highlight else GameConfig.COLOR_TEXT, false)
	h.add_child(s)
	return h

func _stat_row(label: String, value: int) -> Control:
	var h := HBoxContainer.new()
	var l := UITheme.make_label(label, 24, GameConfig.COLOR_TEXT_DIM, false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(UITheme.make_label(str(value), 26, GameConfig.COLOR_TEXT, false))
	return h

func _on_rematch() -> void:
	AudioMan.tap()
	Net.send_rematch()
	rematch_btn.disabled = true
	rematch_status_label.text = "Waiting for opponent…"

func _on_rematch_status(p: Dictionary) -> void:
	var waiting := int(p.get("waitingFor", 1))
	rematch_status_label.text = "Opponent accepted! Starting…" if waiting == 0 else "Waiting for opponent…"

func _bind(sig: Signal, fn: Callable) -> void:
	sig.connect(fn)
	_net_connections.append([sig, fn])

func _unbind_all() -> void:
	for pair in _net_connections:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	_net_connections.clear()
