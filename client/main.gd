extends Control

## Root of the app: safe-area wrapper, screen switching with a quick fade,
## global routing of match events, and the debug overlay.

var _container: Control
var _current: Control
var _debug: DebugPanel

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_container = Control.new()
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_container)
	_apply_safe_area()

	_debug = DebugPanel.new()
	add_child(_debug)

	Net.player_id = Settings.player_id
	Net.display_name = Settings.display_name
	Net.token = Settings.session_token

	Net.match_ended.connect(_on_match_ended)
	Net.reconnect_state.connect(_on_reconnect_state)

	AudioMan.play_music()
	_show_menu()

	if "--smoke" in OS.get_cmdline_user_args() or "--smoke" in OS.get_cmdline_args():
		_run_smoke()
	elif "--net-smoke" in OS.get_cmdline_user_args() or "--net-smoke" in OS.get_cmdline_args():
		_run_net_smoke()
	elif "--shot-menu" in OS.get_cmdline_user_args() or "--shot-menu" in OS.get_cmdline_args():
		_run_shot("menu")
	elif "--shot-match" in OS.get_cmdline_user_args() or "--shot-match" in OS.get_cmdline_args():
		_run_shot("match")
	elif "--shot-clear" in OS.get_cmdline_user_args() or "--shot-clear" in OS.get_cmdline_args():
		_run_shot("clear")
	elif "--shot-mp" in OS.get_cmdline_user_args() or "--shot-mp" in OS.get_cmdline_args():
		_run_shot("mp")
	elif "--shot-settings" in OS.get_cmdline_user_args() or "--shot-settings" in OS.get_cmdline_args():
		_run_shot("settings")
	elif "--shot-results" in OS.get_cmdline_user_args() or "--shot-results" in OS.get_cmdline_args():
		_run_shot("results")

func _apply_safe_area() -> void:
	# Safe-area insets in window pixels; on desktop they are all zero.
	var safe := DisplayServer.get_display_safe_area()
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0 or win.y <= 0:
		return
	var inset_l := maxf(0.0, float(safe.position.x))
	var inset_t := maxf(0.0, float(safe.position.y))
	var inset_r := maxf(0.0, win.x - float(safe.position.x + safe.size.x))
	var inset_b := maxf(0.0, win.y - float(safe.position.y + safe.size.y))
	# convert pixel insets to canvas units
	var scale := get_viewport().get_visible_rect().size / win
	_container.offset_left = inset_l * scale.x
	_container.offset_top = inset_t * scale.y
	_container.offset_right = -inset_r * scale.x
	_container.offset_bottom = -inset_b * scale.y

func _swap(screen: Control) -> void:
	var old := _current
	_current = screen
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.modulate.a = 0.0
	_container.add_child(screen)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(screen, "modulate:a", 1.0, 0.22)
	if old:
		tw.tween_property(old, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(func():
		if is_instance_valid(old):
			old.queue_free())

# ---------------- screens ----------------

func _show_menu() -> void:
	var m := MainMenu.new()
	m.play.connect(func(): _show_match_solo())
	m.duel.connect(_show_mp)
	m.settings.connect(_show_settings)
	m.debug_toggled.connect(func(): Settings.debug_enabled = not Settings.debug_enabled; Settings.save_all())
	_swap(m)

func _show_mp() -> void:
	var s := MultiplayerMenu.new()
	s.back.connect(_show_menu)
	s.match_begin.connect(func(payload): _show_match_mp(payload))
	_swap(s)

func _show_settings() -> void:
	var s := SettingsScreen.new()
	s.back.connect(_show_menu)
	_swap(s)

func _show_match_solo() -> void:
	var s := MatchScreen.new()
	s.setup(false, randi())
	s.exit_to_menu.connect(_show_menu)
	_swap(s)

func _show_match_mp(payload: Dictionary) -> void:
	var s := MatchScreen.new()
	s.setup(true, int(payload.get("seed", 0)), payload)
	s.exit_to_menu.connect(_show_menu)
	_swap(s)

func _show_results(payload: Dictionary) -> void:
	var s := ResultsScreen.new()
	s.setup(payload)
	s.exit_to_menu.connect(_show_menu)
	s.rematch_accepted.connect(func(p): _show_match_mp(p))
	_swap(s)

# ---------------- global match events ----------------

# ---------------- automated smoke test ----------------

## `godot --path client -- --smoke` — boots the real game, plays a solo match,
## and verifies the full pipeline end to end.
func _run_smoke() -> void:
	var errors := 0
	await get_tree().process_frame
	await get_tree().process_frame

	if not (_current is MainMenu):
		printerr("SMOKE FAIL: menu not shown")
		errors += 1

	_show_match_solo()
	await get_tree().create_timer(0.5).timeout
	var ms := _current as MatchScreen
	if ms == null:
		printerr("SMOKE FAIL: match screen missing")
		get_tree().quit(1)
		return

	# play 3 pieces wherever legal
	var placed := 0
	for slot in 3:
		var did := false
		for y in 8:
			for x in 8:
				if not did and ms.controller.can_place(slot, Vector2i(x, y)):
					ms._commit_placement(slot, Vector2i(x, y))
					placed += 1
					did = true
					break
			if did:
				break
	if placed != 3:
		printerr("SMOKE FAIL: only placed %d pieces" % placed)
		errors += 1
	if ms.controller.score <= 0:
		printerr("SMOKE FAIL: score is 0")
		errors += 1
	if ms.controller.set_index != 1:
		printerr("SMOKE FAIL: set did not advance")
		errors += 1

	await get_tree().create_timer(0.5).timeout
	_show_settings()
	await get_tree().create_timer(0.3).timeout
	if not (_current is SettingsScreen):
		printerr("SMOKE FAIL: settings screen missing")
		errors += 1
	_show_menu()

	if errors == 0:
		print("SMOKE OK — solo match played, screens navigated")
	else:
		print("SMOKE FAILED with %d errors" % errors)
	get_tree().quit(1 if errors > 0 else 0)

func _run_net_smoke() -> void:
	var s := NetSmoke.new()
	var code := await s.run(get_tree(), self)
	get_tree().quit(code)

# ---------------- screenshot harness ----------------

## `godot --path client -- --shot-menu|shot-match|shot-clear`
## Renders real frames and writes PNGs to user:// for visual verification.
func _run_shot(mode: String) -> void:
	var dir := "user://shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	if mode == "menu" or mode == "mp" or mode == "settings" or mode == "results":
		if mode == "mp":
			_show_mp()
		elif mode == "settings":
			_show_settings()
		elif mode == "results":
			_show_results({
				"winnerId": Net.player_id,
				"players": [
					{"playerId": Net.player_id, "name": Settings.display_name, "score": 218, "linesCleared": 6, "blocksPlaced": 84, "bestCombo": 3},
					{"playerId": "opp1", "name": "Player 1234", "score": 176, "linesCleared": 4, "blocksPlaced": 71, "bestCombo": 2},
				],
			})
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png(dir + "/" + mode + ".png")
		print("SHOT saved: ", ProjectSettings.globalize_path(dir + "/" + mode + ".png"))
		get_tree().quit(0)
		return

	# play a partial match then capture
	_show_match_solo()
	await get_tree().create_timer(0.6).timeout
	var ms := _current as MatchScreen
	if ms == null:
		get_tree().quit(1)
		return

	if mode == "match":
		for slot in 2:
			_place_first_fit(ms, slot)
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(dir + "/match.png")
		print("SHOT saved: ", ProjectSettings.globalize_path(dir + "/match.png"))
		get_tree().quit(0)
		return

	if mode == "clear":
		# rig the board so one more cell clears a row + column, then capture
		var b := ms.controller.board
		var single := BlockShapes.cells(0)
		for x in range(1, 8):
			b.place(single, Vector2i(x, 0), 2)
		for y in range(1, 8):
			b.place(single, Vector2i(0, y), 4)
		ms.board_view.queue_redraw()
		await get_tree().create_timer(0.3).timeout
		var res := b.place(single, Vector2i(0, 0), 1)
		ms.controller.score += 50
		if res["cleared"].size() > 0:
			var colors := {}
			for c in res["cleared"]:
				colors[c] = GameConfig.PIECE_COLORS[1]
			ms.board_view.flash_clear(res["cleared"], colors)
			ms.fx.celebrate(res["lines"], 3, ms.board_view.get_global_rect().get_center())
		await get_tree().create_timer(0.15).timeout
		get_viewport().get_texture().get_image().save_png(dir + "/clear.png")
		print("SHOT saved: ", ProjectSettings.globalize_path(dir + "/clear.png"))
		get_tree().quit(0)


func _place_first_fit(ms: MatchScreen, slot: int) -> void:
	for y in 8:
		for x in 8:
			if ms.controller.can_place(slot, Vector2i(x, y)):
				ms._commit_placement(slot, Vector2i(x, y))
				return

func _on_match_ended(payload: Dictionary) -> void:
	if _current is MatchScreen or _current is ResultsScreen:
		_show_results(payload)

func _on_reconnect_state(payload: Dictionary) -> void:
	if _current is MatchScreen:
		(_current as MatchScreen).apply_reconnect_state(payload)
	elif _current is ResultsScreen:
		pass
	else:
		# we were mid-match when the app lost the screen — rebuild it
		_show_match_mp({
			"matchId": payload.get("matchId", ""),
			"seed": payload.get("seed", 0),
			"startAtMs": payload.get("startAtMs", 0),
			"durationMs": payload.get("durationMs", 180000),
			"serverNowMs": payload.get("serverNowMs", 0),
			"players": payload.get("players", []),
		})
		if _current is MatchScreen:
			(_current as MatchScreen).apply_reconnect_state(payload)
