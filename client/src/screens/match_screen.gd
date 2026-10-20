class_name MatchScreen
extends Control

## The gameplay screen — used for both solo endless mode and live 1v1 duels.
## Drag & drop, placement preview, clears, combos, HUD, opponent panel,
## countdown, reconnect + game-over overlays all live here.

signal exit_to_menu()

const TRAY_CELL := 30.0

var is_multiplayer := false
var controller: GameController
var match_payload: Dictionary = {}

# layout
var board_view: BoardView
var tray: TrayView
var fx: FxLayer
var content: Control  # shakeable container

# HUD
var score_label: Label
var combo_label: Label
var timer_label: Label
var opp_panel: Control
var opp_name_label: Label
var opp_score_label: Label
var opp_combo_label: Label
var opp_mini: MiniBoardView
var conn_dot: Panel

# overlays
var countdown_layer: Control
var countdown_label: Label
var overlay: PanelContainer        # dim overlay (game over / waiting)
var overlay_title: Label
var overlay_sub: Label
var overlay_buttons: HBoxContainer
var status_pill: PanelContainer    # transient center-top status
var status_label: Label
var _pill_hide_at := 0.0

# drag state
var _drag_slot := -1
var _ghost: PieceView
var _ghost_anchor := Vector2i(-99, -99)
var _ghost_valid := false
var _ghost_home := Vector2.ZERO
var _input_blocked := true

# opponent state
var opp_connected := true
var opp_game_over := false

# timing / anim
var _ends_at_ms := 0.0
var _go_time_ms := 0.0
var _countdown_phase := -1
var _displayed_score := 0.0

func setup(p_is_multiplayer: bool, p_seed: int, p_payload: Dictionary = {}) -> void:
	is_multiplayer = p_is_multiplayer
	match_payload = p_payload
	controller = GameController.new(p_seed)

func _ready() -> void:
	if controller == null:
		controller = GameController.new(randi())
	_build_layout()
	_wire_controller()
	if is_multiplayer:
		_connect_net()
	tray.set_set(controller.current_set().duplicate(), controller.used_slots.duplicate())
	if is_multiplayer:
		_start_countdown(int(match_payload.get("startAtMs", 0)))
	else:
		_input_blocked = false

func _wire_controller() -> void:
	controller.set_renewed.connect(func(_i):
		tray.set_set(controller.current_set().duplicate(), controller.used_slots.duplicate()))

func _build_layout() -> void:
	add_child(UITheme.make_background())

	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	content.add_child(root)

	_build_top_bar(root)

	var board_wrap := CenterContainer.new()
	board_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(board_wrap)

	board_view = BoardView.new()
	board_view.set_state(controller.board)
	board_view.custom_minimum_size = Vector2(690, 760)
	board_wrap.add_child(board_view)

	tray = TrayView.new()
	tray.cell_px = TRAY_CELL
	tray.custom_minimum_size = Vector2(0, 190)
	tray.slot_pressed.connect(_on_slot_pressed)
	root.add_child(tray)

	fx = FxLayer.new()
	fx.shake_target = content
	add_child(fx)

	_build_overlays()

func _build_top_bar(root: VBoxContainer) -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UITheme.panel_style(Color(1, 1, 1, 0.05), 18, Color.TRANSPARENT, 0, false))
	root.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	bar.add_child(h)

	# opponent column (left)
	opp_panel = VBoxContainer.new()
	opp_panel.custom_minimum_size = Vector2(200, 0)
	(opp_panel as VBoxContainer).add_theme_constant_override("separation", 4)
	h.add_child(opp_panel)

	var opp_top := HBoxContainer.new()
	opp_top.add_theme_constant_override("separation", 6)
	opp_panel.add_child(opp_top)
	conn_dot = Panel.new()
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = Color("3ddc84")
	dot_style.set_corner_radius_all(8)
	conn_dot.add_theme_stylebox_override("panel", dot_style)
	conn_dot.custom_minimum_size = Vector2(14, 14)
	conn_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	opp_top.add_child(conn_dot)
	opp_name_label = UITheme.make_label(_opponent_name(), 22, GameConfig.COLOR_TEXT, false)
	opp_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opp_name_label.clip_text = true
	opp_top.add_child(opp_name_label)

	var opp_mid := HBoxContainer.new()
	opp_mid.add_theme_constant_override("separation", 10)
	opp_panel.add_child(opp_mid)
	opp_mini = MiniBoardView.new()
	opp_mini.custom_minimum_size = Vector2(92, 92)
	opp_mid.add_child(opp_mini)
	var opp_right := VBoxContainer.new()
	opp_mid.add_child(opp_right)
	opp_score_label = UITheme.make_label("0", 40, GameConfig.COLOR_ACCENT_2, false)
	opp_right.add_child(opp_score_label)
	opp_combo_label = UITheme.make_label("", 18, GameConfig.COLOR_TEXT_DIM, false)
	opp_right.add_child(opp_combo_label)

	opp_panel.visible = is_multiplayer

	# center: timer + leave
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	h.add_child(mid)
	timer_label = UITheme.make_label("3:00", 48, GameConfig.COLOR_TEXT)
	timer_label.visible = is_multiplayer
	mid.add_child(timer_label)
	var leave_btn := UITheme.make_button("LEAVE", Color("3a3f6e"), 20)
	leave_btn.custom_minimum_size = Vector2(150, 56)
	leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave_btn.pressed.connect(_on_leave_pressed)
	mid.add_child(leave_btn)

	# my column (right)
	var me := VBoxContainer.new()
	me.custom_minimum_size = Vector2(210, 0)
	h.add_child(me)
	me.add_child(UITheme.make_label(_my_name() if is_multiplayer else "SCORE", 22, GameConfig.COLOR_TEXT_DIM, false))
	score_label = UITheme.make_label("0", 52, GameConfig.COLOR_TEXT, false)
	me.add_child(score_label)
	combo_label = UITheme.make_label("", 20, GameConfig.COLOR_ACCENT_2, false)
	me.add_child(combo_label)

func _opponent_name() -> String:
	for p in match_payload.get("players", []):
		if str(p.get("playerId", "")) != Net.player_id:
			return str(p.get("name", "Opponent"))
	return "Opponent"

func _my_name() -> String:
	for p in match_payload.get("players", []):
		if str(p.get("playerId", "")) == Net.player_id:
			return str(p.get("name", "You"))
	return "YOU"

func _build_overlays() -> void:
	countdown_layer = Control.new()
	countdown_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	countdown_layer.visible = false
	add_child(countdown_layer)
	countdown_label = UITheme.make_label("3", 140, GameConfig.COLOR_TEXT)
	countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	countdown_label.position = Vector2(-40, -80)
	countdown_layer.add_child(countdown_label)

	overlay = PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim_style := StyleBoxFlat.new()
	dim_style.bg_color = Color(0.05, 0.05, 0.14, 0.85)
	overlay.add_theme_stylebox_override("panel", dim_style)
	overlay.visible = false
	add_child(overlay)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	overlay.add_child(vb)
	overlay_title = UITheme.make_label("NO MORE MOVES", 58, GameConfig.COLOR_TEXT)
	vb.add_child(overlay_title)
	overlay_sub = UITheme.make_label("", 28, GameConfig.COLOR_TEXT_DIM)
	vb.add_child(overlay_sub)
	overlay_buttons = HBoxContainer.new()
	overlay_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_buttons.add_theme_constant_override("separation", 20)
	vb.add_child(overlay_buttons)

	status_pill = PanelContainer.new()
	status_pill.add_theme_stylebox_override("panel",
		UITheme.panel_style(Color(0.9, 0.55, 0.1, 0.95), 30, Color.TRANSPARENT, 0, false))
	status_pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_pill.position = Vector2(-190, 130)
	status_pill.custom_minimum_size = Vector2(380, 0)
	status_label = UITheme.make_label("", 22, Color.WHITE)
	status_pill.add_child(status_label)
	status_pill.visible = false
	add_child(status_pill)

func _show_pill(text: String, auto_hide_sec := 0.0) -> void:
	status_label.text = text
	status_pill.visible = true
	_pill_hide_at = Time.get_ticks_msec() + auto_hide_sec * 1000.0 if auto_hide_sec > 0 else 0.0

func _hide_pill() -> void:
	status_pill.visible = false
	_pill_hide_at = 0.0

# ---------------- countdown & timing ----------------

func _start_countdown(start_at_ms: int) -> void:
	_input_blocked = true
	countdown_layer.visible = true
	_countdown_phase = -1
	_go_time_ms = start_at_ms - Net.clock_offset_ms

func _process(_delta: float) -> void:
	_update_timer()
	_update_score_anim()
	_update_pill()
	_update_reconnect_pill()
	if countdown_layer.visible:
		var remaining := _go_time_ms - Time.get_ticks_msec()
		var phase := 0 if remaining <= 0 else int(ceil(remaining / 1000.0))
		phase = clampi(phase, 0, 3)
		var key := phase if remaining > 0 else -1
		if key != _countdown_phase:
			_countdown_phase = key
			if phase >= 1 and remaining > 0:
				countdown_label.text = str(phase)
				_pop(countdown_label)
				AudioMan.count()
				Haptics.light()
			else:
				countdown_label.text = "GO!"
				countdown_label.add_theme_color_override("font_color", GameConfig.COLOR_VALID)
				_pop(countdown_label)
				AudioMan.go()
				Haptics.medium()
				_input_blocked = false
				get_tree().create_timer(0.5).timeout.connect(func(): countdown_layer.visible = false)

func _pop(l: Label) -> void:
	l.pivot_offset = Vector2(40, 80)
	l.scale = Vector2(1.6, 1.6)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _update_timer() -> void:
	if not is_multiplayer or _ends_at_ms <= 0.0:
		return
	var remaining := maxf(0.0, _ends_at_ms - Net.server_now_ms())
	var total_s := int(ceil(remaining / 1000.0))
	timer_label.text = "%d:%02d" % [total_s / 60, total_s % 60]
	timer_label.add_theme_color_override("font_color",
		Color("ff5a6e") if total_s <= 15 else GameConfig.COLOR_TEXT)

func _update_score_anim() -> void:
	var target := float(controller.score)
	if _displayed_score != target:
		_displayed_score = lerpf(_displayed_score, target, 0.28)
		if absf(target - _displayed_score) < 0.6:
			_displayed_score = target
		score_label.text = str(int(_displayed_score))

func _update_pill() -> void:
	if _pill_hide_at > 0.0 and Time.get_ticks_msec() > _pill_hide_at:
		_hide_pill()

func _update_reconnect_pill() -> void:
	if not is_multiplayer:
		return
	if Net.reconnecting:
		_show_pill("Reconnecting…")
	elif status_label.text == "Reconnecting…" and not opp_game_over_pill_needed():
		_hide_pill()

func opp_game_over_pill_needed() -> bool:
	return not opp_connected

func set_match_timing(payload: Dictionary) -> void:
	var start_at := float(payload.get("startAtMs", 0))
	var dur := float(payload.get("durationMs", 180000))
	_ends_at_ms = start_at + dur

# ---------------- networking wiring ----------------

var _net_connections: Array = []

func _connect_net() -> void:
	_bind(Net.opponent_board, _on_opponent_board)
	_bind(Net.opponent_disconnected, _on_opp_disc)
	_bind(Net.opponent_reconnected, _on_opp_recon)
	_bind(Net.opponent_game_over, _on_opp_game_over)
	_bind(Net.place_rejected, _on_place_rejected)
	_bind(Net.board_sync, _on_board_sync)
	_bind(Net.tick, _on_tick)
	set_match_timing(match_payload)
	tree_exiting.connect(_unbind_all)

func _bind(sig: Signal, fn: Callable) -> void:
	sig.connect(fn)
	_net_connections.append([sig, fn])

func _unbind_all() -> void:
	for pair in _net_connections:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	_net_connections.clear()

func _on_tick(remaining_ms: int) -> void:
	_ends_at_ms = Net.server_now_ms() + remaining_ms

func _on_opponent_board(p: Dictionary) -> void:
	opp_mini.set_mask(p.get("board", []))
	opp_score_label.text = str(int(p.get("score", 0)))
	var combo := int(p.get("combo", 0))
	opp_combo_label.text = "COMBO x%d" % combo if combo >= 2 else ""
	opp_connected = true
	conn_dot.get_theme_stylebox("panel").bg_color = Color("3ddc84")

func _on_opp_disc(_p: Dictionary) -> void:
	opp_connected = false
	conn_dot.get_theme_stylebox("panel").bg_color = Color("ffb84d")
	_show_pill("Opponent reconnecting…")

func _on_opp_recon(_p: Dictionary) -> void:
	opp_connected = true
	conn_dot.get_theme_stylebox("panel").bg_color = Color("3ddc84")
	if status_label.text == "Opponent reconnecting…":
		_hide_pill()

func _on_opp_game_over(p: Dictionary) -> void:
	opp_game_over = true
	_show_pill("Opponent finished — %d pts" % int(p.get("score", 0)), 3.0)

func _on_place_rejected(p: Dictionary) -> void:
	push_warning("Placement rejected: %s" % str(p.get("code", "?")))

func _on_board_sync(p: Dictionary) -> void:
	var mask: Array = p.get("board", [])
	if mask.size() == 8:
		controller.board.from_bitmask(mask)
		controller.score = int(p.get("score", controller.score))
		controller.combo = int(p.get("combo", controller.combo))
		board_view.queue_redraw()

func _on_leave_pressed() -> void:
	if is_multiplayer:
		Net.leave_room()
		Net.reset_to_idle()
	exit_to_menu.emit()

# ---------------- drag & drop ----------------

func _input(event: InputEvent) -> void:
	if _drag_slot < 0 or _ghost == null:
		return
	if event is InputEventScreenDrag:
		_update_drag(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_release_drag()
	elif event is InputEventMouseMotion:
		_update_drag(event.position)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_release_drag()

func _on_slot_pressed(slot: int, global_pos: Vector2) -> void:
	if _input_blocked or not controller.slot_available(slot) or _drag_slot >= 0:
		return
	_drag_slot = slot
	_ghost_home = tray.slot_center(slot)
	_ghost = PieceView.new()
	_ghost.set_shape(controller.slot_shape_index(slot), board_view.cell_px, true)
	_ghost.z_index = 50
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)
	_ghost.scale = Vector2(0.4, 0.4)
	_ghost.create_tween().tween_property(_ghost, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tray.clear_slot(slot)
	AudioMan.pickup()
	Haptics.light()
	_update_drag(global_pos)

func _update_drag(finger_pos: Vector2) -> void:
	var ghost_size := _ghost.pixel_size()
	# Lift the piece above the finger, centered horizontally.
	_ghost.global_position = finger_pos - Vector2(ghost_size.x * 0.5, ghost_size.y + GameConfig.DRAG_LIFT_PX)
	# The ghost's top-left corner = the shape's (0,0) cell top-left.
	var board_local: Vector2 = board_view.get_global_transform().affine_inverse() * _ghost.get_global_rect().position
	var anchor := board_view.pos_to_cell(board_local)
	var shape := controller.slot_shape(_drag_slot)
	var valid := controller.can_place(_drag_slot, anchor)
	if anchor != _ghost_anchor or valid != _ghost_valid:
		var was_valid := _ghost_valid
		_ghost_anchor = anchor
		_ghost_valid = valid
		if _fits_partially(anchor, shape):
			board_view.show_preview(shape, anchor, valid)
		else:
			board_view.clear_preview()
		if valid and not was_valid:
			Haptics.light()
			AudioMan.snap()

func _fits_partially(anchor: Vector2i, shape: Array) -> bool:
	for off in shape:
		var c: Vector2i = anchor + off
		if BoardState.in_bounds(c.x, c.y):
			return true
	return false

func _release_drag() -> void:
	var slot := _drag_slot
	var anchor := _ghost_anchor
	var valid := _ghost_valid
	_drag_slot = -1
	board_view.clear_preview()
	if _ghost == null:
		return
	var ghost := _ghost
	_ghost = null

	if valid:
		var snap_pos := board_view.get_global_rect().position + board_view.cell_top_left_pos(anchor)
		var tw := ghost.create_tween()
		tw.tween_property(ghost, "global_position", snap_pos, GameConfig.SNAP_TWEEN_TIME)
		tw.tween_callback(ghost.queue_free)
		_commit_placement(slot, anchor)
	else:
		AudioMan.invalid()
		var small := TRAY_CELL / board_view.cell_px
		var tw := ghost.create_tween().set_parallel(true)
		tw.tween_property(ghost, "global_position", _ghost_home - ghost.pixel_size() * small * 0.5, GameConfig.RETURN_TWEEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ghost, "scale", Vector2.ONE * small, GameConfig.RETURN_TWEEN_TIME)
		tw.chain().tween_callback(func():
			ghost.queue_free()
			tray.set_slot_shape(slot, controller.slot_shape_index(slot)))

func _commit_placement(slot: int, anchor: Vector2i) -> void:
	var pre_cells := controller.board.cells.duplicate()
	var res := controller.place(slot, anchor)
	if not res.get("ok", false):
		return

	var cleared: Array = res["cleared"]
	var colors := {}
	for c in cleared:
		var v: int = pre_cells[c.y * GameConfig.BOARD_SIZE + c.x]
		colors[c] = GameConfig.PIECE_COLORS[(v - 1) % GameConfig.PIECE_COLORS.size()] if v > 0 else GameConfig.COLOR_TEXT

	board_view.queue_redraw()
	board_view.pulse_cells(res["placed"])
	if cleared.size() > 0:
		board_view.flash_clear(cleared, colors)
		AudioMan.clear_lines(res["lines"])
		fx.celebrate(res["lines"], res["combo"], board_view.get_global_rect().get_center())
	else:
		AudioMan.place()
		Haptics.light()

	fx.floating_text("+%d" % res["gained"],
		board_view.get_global_rect().get_center() + Vector2(0, -board_view.size.y * 0.38),
		GameConfig.COLOR_GOLD if res["lines"] > 0 else GameConfig.COLOR_TEXT_DIM,
		40 if res["lines"] > 0 else 26)
	_displayed_score = float(controller.score) - float(res["gained"])

	if res["combo"] >= 2:
		combo_label.text = "COMBO x%d" % res["combo"]
		AudioMan.combo(res["combo"])
	else:
		combo_label.text = ""

	if is_multiplayer:
		Net.send_placement(int(res["placed_set_index"]), slot, res["placed"])

	if res.get("game_over", false):
		_on_self_game_over()

func _on_self_game_over() -> void:
	_input_blocked = true
	overlay_title.text = "NO MORE MOVES"
	overlay_sub.text = "Final score: %d" % controller.score
	if is_multiplayer:
		overlay_sub.text += " — waiting for opponent…"
	overlay.visible = true
	AudioMan.game_over()
	if is_multiplayer:
		Net.send_game_over()
	else:
		var restart := UITheme.make_button("RESTART", GameConfig.COLOR_ACCENT, 26)
		restart.pressed.connect(_solo_restart)
		var menu := UITheme.make_button("MENU", Color("3a3f6e"), 26)
		menu.pressed.connect(func(): exit_to_menu.emit())
		overlay_buttons.add_child(restart)
		overlay_buttons.add_child(menu)

func _solo_restart() -> void:
	for b in overlay_buttons.get_children():
		b.queue_free()
	overlay.visible = false
	controller = GameController.new(randi())
	_wire_controller()
	board_view.set_state(controller.board)
	board_view.queue_redraw()
	tray.set_set(controller.current_set().duplicate(), controller.used_slots.duplicate())
	_displayed_score = 0
	score_label.text = "0"
	combo_label.text = ""
	_input_blocked = false

## Rehydrate after reconnect (RECONNECT_STATE from server).
func apply_reconnect_state(p: Dictionary) -> void:
	var you: Dictionary = p.get("you", {})
	match_payload["startAtMs"] = p.get("startAtMs", 0)
	match_payload["durationMs"] = p.get("durationMs", 180000)
	match_payload["players"] = p.get("players", match_payload.get("players", []))
	_ends_at_ms = Net.server_now_ms() + float(p.get("remainingMs", 0))
	controller.apply_server_state(
		you.get("boardCells", []), int(you.get("score", 0)), int(you.get("combo", 0)),
		int(you.get("setIndex", 0)), you.get("usedSlots", []), bool(you.get("gameOver", false)))
	var opp: Dictionary = p.get("opponent", {})
	opp_score_label.text = str(int(opp.get("score", 0)))
	opp_mini.set_mask(opp.get("board", []))
	opp_name_label.text = str(opp.get("name", "Opponent"))
	opp_game_over = bool(opp.get("gameOver", false))
	board_view.queue_redraw()
	tray.set_set(controller.current_set().duplicate(), controller.used_slots.duplicate())
	countdown_layer.visible = false
	if controller.is_game_over:
		_input_blocked = true
		_on_self_game_over()
	else:
		_input_blocked = false
