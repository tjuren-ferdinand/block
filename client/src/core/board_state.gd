class_name BoardState
extends RefCounted

## 8x8 board logic — behavioral mirror of server/src/game/board.ts.
## cells[y * 8 + x]; 0 = empty, >0 = color id.

const SIZE := GameConfig.BOARD_SIZE

var cells: PackedByteArray

func _init() -> void:
	cells = PackedByteArray()
	cells.resize(SIZE * SIZE)

func clone() -> BoardState:
	var b := BoardState.new()
	b.cells = cells.duplicate()
	return b

func get_cell(x: int, y: int) -> int:
	return cells[y * SIZE + x]

func is_empty(x: int, y: int) -> bool:
	return cells[y * SIZE + x] == 0

static func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < SIZE and y >= 0 and y < SIZE

## shape_cells: Array[Vector2i] offsets; anchor = Vector2i(col,row) of top-left.
func can_place(shape_cells: Array, anchor: Vector2i) -> bool:
	for off in shape_cells:
		var x: int = anchor.x + off.x
		var y: int = anchor.y + off.y
		if not in_bounds(x, y) or cells[y * SIZE + x] != 0:
			return false
	return true

## Place a shape; fills cells then clears complete rows/columns.
## Returns {placed: Array[Vector2i], cleared: Array[Vector2i], lines: int,
##          cleared_rows: Array[int], cleared_cols: Array[int]}
func place(shape_cells: Array, anchor: Vector2i, color_id: int) -> Dictionary:
	var placed: Array[Vector2i] = []
	for off in shape_cells:
		var x: int = anchor.x + off.x
		var y: int = anchor.y + off.y
		cells[y * SIZE + x] = color_id
		placed.append(Vector2i(x, y))

	var rows: Array[int] = []
	var cols: Array[int] = []
	for y in SIZE:
		var full := true
		for x in SIZE:
			if cells[y * SIZE + x] == 0:
				full = false
				break
		if full:
			rows.append(y)
	for x in SIZE:
		var full := true
		for y in SIZE:
			if cells[y * SIZE + x] == 0:
				full = false
				break
		if full:
			cols.append(x)

	var cleared: Array[Vector2i] = []
	var seen := {}
	for y in rows:
		for x in SIZE:
			cells[y * SIZE + x] = 0
			var v := Vector2i(x, y)
			if not seen.has(v):
				seen[v] = true
				cleared.append(v)
	for x in cols:
		for y in SIZE:
			var key := Vector2i(x, y)
			if cells[y * SIZE + x] != 0:
				cells[y * SIZE + x] = 0
				if not seen.has(key):
					seen[key] = true
					cleared.append(key)

	return {
		"placed": placed,
		"cleared": cleared,
		"lines": rows.size() + cols.size(),
		"cleared_rows": rows,
		"cleared_cols": cols,
	}

## Does this shape fit anywhere?
func any_placement_for_shape(shape_cells: Array) -> bool:
	var b := BlockShapes.bounds_of(shape_cells)
	for y in SIZE - b.y + 1:
		for x in SIZE - b.x + 1:
			if can_place(shape_cells, Vector2i(x, y)):
				return true
	return false

## Does ANY of the given shapes fit? (game-over check)
func any_placement_for_shapes(shape_list: Array) -> bool:
	for shape_cells in shape_list:
		if any_placement_for_shape(shape_cells):
			return true
	return false

## 8 row bitmasks — same encoding as server boardToBitmask.
func to_bitmask() -> Array[int]:
	var rows: Array[int] = []
	for y in SIZE:
		var bits := 0
		for x in SIZE:
			if cells[y * SIZE + x] != 0:
				bits |= 1 << x
		rows.append(bits)
	return rows

func from_bitmask(mask: Array) -> void:
	for y in SIZE:
		var bits: int = mask[y] if y < mask.size() else 0
		for x in SIZE:
			cells[y * SIZE + x] = 1 if (bits & (1 << x)) != 0 else 0

func from_cell_array(arr: Array) -> void:
	for i in mini(arr.size(), SIZE * SIZE):
		cells[i] = int(arr[i])

func filled_count() -> int:
	var n := 0
	for i in SIZE * SIZE:
		if cells[i] != 0:
			n += 1
	return n
