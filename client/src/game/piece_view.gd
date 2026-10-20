class_name PieceView
extends Control

## Draws a single block piece (shape cells) at a given cell pixel size.
## Used inside tray slots and as the floating drag ghost.

var shape_index := -1
var cell_px := 26.0
var ghost := false

var _cells: Array = []
var _bounds := Vector2i.ONE

func set_shape(p_shape_index: int, p_cell_px: float, p_ghost := false) -> void:
	shape_index = p_shape_index
	cell_px = p_cell_px
	ghost = p_ghost
	_cells = BlockShapes.cells(shape_index)
	_bounds = BlockShapes.bounds_of(_cells)
	custom_minimum_size = Vector2(_bounds.x * cell_px, _bounds.y * cell_px)
	size = custom_minimum_size
	queue_redraw()

func pixel_size() -> Vector2:
	return Vector2(_bounds.x * cell_px, _bounds.y * cell_px)

func _draw() -> void:
	if shape_index < 0:
		return
	var origin := (size - pixel_size()) * 0.5
	var color := GameConfig.piece_color(shape_index)
	if ghost:
		color.a = 0.92
	var style := UITheme.cell_style(color, int(cell_px * 0.16))
	var hi := UITheme.cell_style(Color(1, 1, 1, 0.22), int(cell_px * 0.14))
	for off in _cells:
		var r := Rect2(origin + Vector2(off.x * cell_px, off.y * cell_px), Vector2(cell_px, cell_px))
		draw_style_box(style, r.grow(-cell_px * 0.05))
		draw_style_box(hi, Rect2(r.position + Vector2(3, 3) + Vector2(cell_px * 0.05, cell_px * 0.05), Vector2(r.size.x - 6 - cell_px * 0.1, r.size.y * 0.3)))
