class_name UITheme
extends RefCounted

## Shared styling helpers for the code-built UI: rounded panels, buttons,
## labels. Keeps every screen consistent with the game's visual identity.

static func panel_style(bg: Color, radius := 18, border := Color.TRANSPARENT, border_w := 0, shadow := true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

static func cell_style(bg: Color, radius := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	return s

static func button_style(base: Color, radius := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = base
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

static func make_button(text: String, base: Color, font_size := 30) -> Button:
	var b := Button.new()
	b.text = text
	var normal := button_style(base)
	var hover := button_style(base.lightened(0.08))
	var pressed := button_style(base.darkened(0.15))
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(0, 84)
	return b

static func make_label(text: String, size := 28, color := GameConfig.COLOR_TEXT, bold_center := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold_center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func make_pill(text: String, bg: Color, font_size := 22, text_color := Color.WHITE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, 40, Color.TRANSPARENT, 0, false))
	var l := make_label(text, font_size, text_color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

## Gradient background covering the whole viewport.
static func make_background() -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, GameConfig.COLOR_BG_TOP)
	grad.set_color(1, GameConfig.COLOR_BG_BOTTOM)
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.3, 0)
	tex.fill_to = Vector2(0.7, 1)
	tex.width = 64
	tex.height = 256
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
