class_name MainMenu
extends Control

## Animated main menu: logo, PLAY / MULTIPLAYER / SETTINGS.

signal play()
signal duel()
signal settings()
signal debug_toggled()

var _tap_count := 0
var _last_tap := 0

func _ready() -> void:
	add_child(UITheme.make_background())

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 26)
	add_child(root)

	# ---- logo: 2x2 colored tiles + title ----
	var logo_wrap := VBoxContainer.new()
	logo_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_wrap.add_theme_constant_override("separation", 8)
	root.add_child(logo_wrap)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo_wrap.add_child(grid)
	for i in 4:
		var tile := Panel.new()
		tile.custom_minimum_size = Vector2(72, 72)
		tile.add_theme_stylebox_override("panel", UITheme.cell_style(GameConfig.PIECE_COLORS[i], 16))
		grid.add_child(tile)
		tile.pivot_offset = Vector2(36, 36)
		tile.scale = Vector2.ZERO
		var tw := tile.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_interval(0.08 * i)
		tw.tween_property(tile, "scale", Vector2.ONE, 0.3)
	# idle bobbing
	for i in 4:
		var tile: Panel = grid.get_child(i)
		var bob := tile.create_tween().set_loops()
		bob.tween_interval(0.15 * i)
		bob.tween_property(tile, "position:y", tile.position.y - 6, 1.1).set_trans(Tween.TRANS_SINE)
		bob.tween_property(tile, "position:y", tile.position.y, 1.1).set_trans(Tween.TRANS_SINE)

	var title := UITheme.make_label(GameConfig.GAME_NAME, 78, GameConfig.COLOR_TEXT)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	title.add_theme_constant_override("outline_size", 10)
	logo_wrap.add_child(title)
	var subtitle := UITheme.make_label("realtime block battles", 24, GameConfig.COLOR_TEXT_DIM)
	logo_wrap.add_child(subtitle)

	# title is also the hidden debug toggle (triple tap)
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.gui_input.connect(_on_title_tapped)

	# ---- buttons ----
	var btn_box := VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 18)
	btn_box.custom_minimum_size = Vector2(420, 0)
	btn_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(btn_box)

	var play_btn := UITheme.make_button("PLAY", GameConfig.COLOR_ACCENT, 34)
	play_btn.pressed.connect(func(): AudioMan.tap(); play.emit())
	btn_box.add_child(play_btn)

	var mp_btn := UITheme.make_button("MULTIPLAYER", Color("25b3a0"), 34)
	mp_btn.pressed.connect(func(): AudioMan.tap(); duel.emit())
	btn_box.add_child(mp_btn)

	var set_btn := UITheme.make_button("SETTINGS", Color("3a3f6e"), 30)
	set_btn.pressed.connect(func(): AudioMan.tap(); settings.emit())
	btn_box.add_child(set_btn)

	var ver := UITheme.make_label("v%s" % GameConfig.GAME_VERSION, 18, GameConfig.COLOR_TEXT_DIM)
	root.add_child(ver)

	# entrance
	modulate.a = 0.0
	var intro := create_tween()
	intro.tween_property(self, "modulate:a", 1.0, 0.3)

func _on_title_tapped(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		var now := Time.get_ticks_msec()
		_tap_count = _tap_count + 1 if now - _last_tap < 600 else 1
		_last_tap = now
		if _tap_count >= 3:
			_tap_count = 0
			debug_toggled.emit()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_title_tapped_screen_touch()

func _on_title_tapped_screen_touch() -> void:
	var now := Time.get_ticks_msec()
	_tap_count = _tap_count + 1 if now - _last_tap < 600 else 1
	_last_tap = now
	if _tap_count >= 3:
		_tap_count = 0
		debug_toggled.emit()
