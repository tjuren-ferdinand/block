class_name MiniBoardView
extends Control

## Compact 8x8 occupancy view fed by the server's BOARD_UPDATE bitmasks.

var mask: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
var block_color := GameConfig.COLOR_ACCENT

func _ready() -> void:
	custom_minimum_size = Vector2(120, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_mask(rows: Array) -> void:
	for i in mini(rows.size(), 8):
		mask[i] = int(rows[i])
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y)
	var cell := s / 8.0
	var bg := UITheme.panel_style(GameConfig.COLOR_BOARD, 10, Color.TRANSPARENT, 0, false)
	draw_style_box(bg, Rect2(Vector2.ZERO, Vector2(s, s)))
	var fill := UITheme.cell_style(block_color, int(cell * 0.2))
	for y in 8:
		for x in 8:
			if (mask[y] & (1 << x)) != 0:
				draw_style_box(fill, Rect2(Vector2(x * cell, y * cell) + Vector2(1, 1), Vector2(cell - 2, cell - 2)))
