class_name SettingsScreen
extends Control

## Settings: player name, volumes, haptics, debug toggle. Persisted instantly.

signal back()

func _ready() -> void:
	add_child(UITheme.make_background())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	root.add_child(UITheme.make_label("SETTINGS", 48, GameConfig.COLOR_TEXT))

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.panel_style(Color(1, 1, 1, 0.05), 22))
	card.custom_minimum_size = Vector2(620, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 16)
	card.add_child(cv)

	# name
	cv.add_child(UITheme.make_label("PLAYER NAME", 22, GameConfig.COLOR_TEXT_DIM, false))
	var name_edit := LineEdit.new()
	name_edit.text = Settings.display_name
	name_edit.max_length = 24
	name_edit.add_theme_font_size_override("font_size", 30)
	name_edit.custom_minimum_size = Vector2(0, 72)
	name_edit.add_theme_stylebox_override("normal", UITheme.panel_style(Color(0, 0, 0, 0.3), 14, GameConfig.COLOR_CELL_EDGE, 2, false))
	name_edit.text_changed.connect(func(t): Settings.set_display_name(t); Net.display_name = Settings.display_name)
	cv.add_child(name_edit)

	cv.add_child(_slider("SOUND FX", Settings.sfx_volume, func(v): Settings.sfx_volume = v; AudioMan.apply_volumes(); AudioMan.tap()))
	cv.add_child(_slider("MUSIC", Settings.music_volume, func(v): Settings.music_volume = v; AudioMan.apply_volumes()))
	cv.add_child(_slider("MASTER VOLUME", Settings.master_volume, func(v): Settings.master_volume = v; AudioMan.apply_volumes()))

	var haptic := CheckButton.new()
	haptic.text = "Haptic feedback"
	haptic.button_pressed = Settings.haptics_enabled
	haptic.add_theme_font_size_override("font_size", 28)
	haptic.toggled.connect(func(on): Settings.haptics_enabled = on; Settings.save_all(); if on: Haptics.medium())
	cv.add_child(haptic)

	var debug := CheckButton.new()
	debug.text = "Debug overlay"
	debug.button_pressed = Settings.debug_enabled
	debug.add_theme_font_size_override("font_size", 28)
	debug.toggled.connect(func(on): Settings.debug_enabled = on; Settings.save_all())
	cv.add_child(debug)

	var id_label := UITheme.make_label("ID: %s" % Settings.player_id, 18, GameConfig.COLOR_TEXT_DIM, false)
	cv.add_child(id_label)

	var back_btn := UITheme.make_button("DONE", GameConfig.COLOR_ACCENT, 30)
	back_btn.custom_minimum_size = Vector2(320, 80)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.pressed.connect(func(): AudioMan.tap(); Settings.save_all(); back.emit())
	root.add_child(back_btn)

func _slider(label: String, value: float, on_change: Callable) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	var l := UITheme.make_label(label, 22, GameConfig.COLOR_TEXT_DIM, false)
	vb.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(0, 48)
	s.value_changed.connect(on_change)
	s.value_changed.connect(func(_v): Settings.save_all())
	vb.add_child(s)
	return vb
