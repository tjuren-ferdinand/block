class_name BoardView
extends Control

## Renders the 8x8 board: cells, placed blocks, placement ghost preview,
## clear flashes and placement pulses. Pure drawing + tweens, no textures.

var state: BoardState

var pad_px := 10.0
var gap_px := 6.0
var cell_px := 40.0
var board_origin := Vector2.ZERO

var _preview_cells: Array = []       # Vector2i board cells
var _preview_valid := false
var _preview_color := GameConfig.COLOR_VALID
var _pulse: Dictionary = {}          # Vector2i -> t (0..1 shrinking bounce)
var _clearing: Dictionary = {}       # Vector2i -> t (0..1 fade-out)
var _clear_color: Dictionary = {}    # Vector2i -> Color

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(200, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_state(s: BoardState) -> void:
	state = s
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recalc()
		queue_redraw()

func _recalc() -> void:
	var w := size.x
	cell_px = (w - pad_px * 2.0 - gap_px * (GameConfig.BOARD_SIZE - 1)) / GameConfig.BOARD_SIZE
	board_origin = Vector2(pad_px, (size.y - w) / 2.0 + pad_px)

func cell_rect(cell: Vector2i) -> Rect2:
	var pos := board_origin + Vector2(cell.x * (cell_px + gap_px), cell.y * (cell_px + gap_px))
	return Rect2(pos, Vector2(cell_px, cell_px))

## Map a position in THIS control's local coords to a board cell anchor
## (top-left cell of the dragged shape sits on that cell). Returns (-1,-1) when
## outside the grid area.
func pos_to_cell(p: Vector2) -> Vector2i:
	var rel := p - board_origin
	var step := cell_px + gap_px
	var x := int(floor(rel.x / step))
	var y := int(floor(rel.y / step))
	if x < -1 or y < -1 or x > GameConfig.BOARD_SIZE or y > GameConfig.BOARD_SIZE:
		return Vector2i(-99, -99)
	return Vector2i(x, y)

func cell_top_left_pos(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(cell.x * (cell_px + gap_px), cell.y * (cell_px + gap_px))

func show_preview(shape_cells: Array, anchor: Vector2i, valid: bool) -> void:
	_preview_cells.clear()
	for off in shape_cells:
		_preview_cells.append(anchor + off)
	_preview_valid = valid
	_preview_color = GameConfig.COLOR_VALID if valid else GameConfig.COLOR_INVALID
	queue_redraw()

func clear_preview() -> void:
	_preview_cells.clear()
	queue_redraw()

func pulse_cells(cells: Array) -> void:
	for c in cells:
		_pulse[c] = 0.0
	var tw := create_tween()
	tw.tween_method(_pulse_step, 0.0, 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _pulse_step(v: float) -> void:
	for c in _pulse.keys():
		_pulse[c] = v
	if v >= 1.0:
		_pulse.clear()
	queue_redraw()

func flash_clear(cells: Array, colors: Dictionary) -> void:
	for c in cells:
		_clearing[c] = 0.0
		_clear_color[c] = colors.get(c, GameConfig.COLOR_TEXT)
	var tw := create_tween()
	tw.tween_method(_clear_step, 0.0, 1.0, GameConfig.CLEAR_ANIM_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _clear_step(v: float) -> void:
	for c in _clearing.keys():
		_clearing[c] = v
	if v >= 1.0:
		_clearing.clear()
		_clear_color.clear()
	queue_redraw()

func _draw() -> void:
	if state == null:
		return
	var board_rect := Rect2(board_origin - Vector2(pad_px, pad_px), Vector2(size.x - 0, cell_px * 8 + gap_px * 7 + pad_px * 2))
	draw_style_box(UITheme.panel_style(GameConfig.COLOR_BOARD, 20, GameConfig.COLOR_CELL_EDGE, 2, false), board_rect)

	var empty_style := UITheme.cell_style(GameConfig.COLOR_CELL, int(cell_px * 0.16))
	for y in GameConfig.BOARD_SIZE:
		for x in GameConfig.BOARD_SIZE:
			draw_style_box(empty_style, cell_rect(Vector2i(x, y)))

	# occupied cells
	for y in GameConfig.BOARD_SIZE:
		for x in GameConfig.BOARD_SIZE:
			var v := state.get_cell(x, y)
			if v == 0:
				continue
			var cell := Vector2i(x, y)
			var r := cell_rect(cell)
			if _pulse.has(cell):
				var t: float = _pulse[cell]
				var sc := 1.0 + 0.18 * sin(t * PI)
				var grown := r.grow((sc - 1.0) * cell_px * 0.5)
				_draw_block(grown, GameConfig.PIECE_COLORS[(v - 1) % GameConfig.PIECE_COLORS.size()])
			else:
				_draw_block(r, GameConfig.PIECE_COLORS[(v - 1) % GameConfig.PIECE_COLORS.size()])

	# clearing flash (cells already emptied in state — draw fading overlay)
	for cell in _clearing.keys():
		var t: float = _clearing[cell]
		var r := cell_rect(cell)
		var col: Color = _clear_color.get(cell, Color.WHITE)
		col.a = 1.0 - t
		var shrunk := r.grow(-t * cell_px * 0.4)
		var s := UITheme.cell_style(col.lerp(Color.WHITE, t * 0.6), int(cell_px * 0.16))
		draw_style_box(s, shrunk)

	# placement preview
	if _preview_cells.size() > 0:
		var style := UITheme.cell_style(Color(_preview_color, GameConfig.PREVIEW_ALPHA), int(cell_px * 0.16))
		for cell in _preview_cells:
			if not BoardState.in_bounds(cell.x, cell.y):
				continue
			var r := cell_rect(cell)
			draw_style_box(style, r)
			if not _preview_valid:
				var line := StyleBoxFlat.new()
				line.bg_color = Color(0, 0, 0, 0)
				line.border_color = GameConfig.COLOR_INVALID
				line.set_border_width_all(2)
				line.set_corner_radius_all(int(cell_px * 0.16))
				draw_style_box(line, r)

## A placed block: base rounded rect + glossy top highlight for depth.
func _draw_block(r: Rect2, color: Color) -> void:
	var base := UITheme.cell_style(color, int(cell_px * 0.16))
	draw_style_box(base, r)
	var highlight := UITheme.cell_style(Color(1, 1, 1, 0.22), int(cell_px * 0.14))
	draw_style_box(highlight, Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, r.size.y * 0.34)))
	var shade := UITheme.cell_style(Color(0, 0, 0, 0.16), int(cell_px * 0.14))
	draw_style_box(shade, Rect2(r.position + Vector2(3, r.size.y - r.size.y * 0.26), Vector2(r.size.x - 6, r.size.y * 0.22)))
