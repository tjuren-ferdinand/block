class_name FxLayer
extends Control

## Full-screen overlay for juice: block-burst particles on clears, floating
## score text, big combo banners, and screen shake of a target node.

var shake_target: Control
var _shake_strength := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()

func _process(delta: float) -> void:
	if shake_target and _shake_strength > 0.1:
		_shake_strength = lerpf(_shake_strength, 0.0, delta * 9.0)
		shake_target.position = Vector2(
			_rng.randf_range(-_shake_strength, _shake_strength),
			_rng.randf_range(-_shake_strength, _shake_strength))
	elif shake_target:
		shake_target.position = Vector2.ZERO

func shake(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)

## Floating "+42" text that rises and fades.
func floating_text(text: String, at: Vector2, color := GameConfig.COLOR_GOLD, size := 36) -> void:
	var l := UITheme.make_label(text, size, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	l.position = at - Vector2(l.size.x * 0.5, 0)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 90, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(l.queue_free)

## Big center-screen banner: "DOUBLE CLEAR!", "COMBO x3", "GO!"
func banner(text: String, color := GameConfig.COLOR_GOLD, font_size := 64) -> void:
	var l := UITheme.make_label(text, font_size, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("outline_size", 10)
	add_child(l)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.position = Vector2(font_size * -text.length() * 0.28, -60)
	l.pivot_offset = Vector2(text.length() * font_size * 0.28, 40)
	l.scale = Vector2(0.3, 0.3)
	l.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "modulate:a", 1.0, 0.12)
	tw.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.55)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(l.queue_free)

## Burst of small squares at a position.
func burst(at: Vector2, color: Color, count := 14, spread := 260.0) -> void:
	for i in count:
		var p := ColorRect.new()
		var sz := _rng.randf_range(8, 16)
		p.size = Vector2(sz, sz)
		p.color = color.lightened(_rng.randf_range(-0.1, 0.25))
		p.position = at
		p.rotation = _rng.randf_range(0, TAU)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		var dir := Vector2.RIGHT.rotated(_rng.randf_range(0, TAU))
		var dist := _rng.randf_range(spread * 0.3, spread)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "position", at + dir * dist, _rng.randf_range(0.35, 0.6)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation", p.rotation + _rng.randf_range(-3, 3), 0.5)
		tw.tween_property(p, "modulate:a", 0.0, _rng.randf_range(0.35, 0.55))
		tw.chain().tween_callback(p.queue_free)

## Celebrate a multi-line clear centered on the board.
func celebrate(lines: int, combo: int, center: Vector2) -> void:
	if lines >= 2:
		var words := {2: "DOUBLE CLEAR!", 3: "TRIPLE CLEAR!"}
		banner(words.get(lines, "MEGA CLEAR x%d!" % lines), GameConfig.COLOR_GOLD, 58)
		shake(minf(6 + lines * 4, 22))
		Haptics.heavy()
		for i in mini(lines + 1, 5):
			burst(center + Vector2(_rng.randf_range(-140, 140), _rng.randf_range(-140, 140)), GameConfig.piece_color(i), 12, 320)
	elif combo >= 2:
		banner("COMBO x%d" % combo, GameConfig.COLOR_ACCENT_2, 52)
		shake(6)
		Haptics.medium()
	elif lines == 1:
		Haptics.light()
