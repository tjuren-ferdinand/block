class_name GameController
extends RefCounted

## Client-side game state for one player: board, score, combo, current set.
## Used for solo mode and as the local mirror in multiplayer (the server is
## authoritative — see MatchClient; on mismatch the UI resyncs to the server).

signal placed(result: Dictionary)
signal set_renewed(set_index: int)
signal game_over()

var seed: int
var board: BoardState
var score := 0
var combo := 0
var best_combo := 0
var lines_cleared := 0
var blocks_placed := 0
var set_index := 0
var used_slots: Array[bool] = [false, false, false]
var is_game_over := false

func _init(p_seed: int) -> void:
	seed = p_seed
	board = BoardState.new()

func current_set() -> Array[int]:
	return PieceGenerator.generate_set(seed, set_index)

func slot_shape(slot: int) -> Array:
	return BlockShapes.cells(current_set()[slot])

func slot_shape_index(slot: int) -> int:
	return current_set()[slot]

func slot_available(slot: int) -> bool:
	return slot >= 0 and slot < GameConfig.PIECES_PER_SET and not used_slots[slot] and not is_game_over

func can_place(slot: int, anchor: Vector2i) -> bool:
	if not slot_available(slot):
		return false
	return board.can_place(slot_shape(slot), anchor)

func remaining_shapes() -> Array:
	var out: Array = []
	var set := current_set()
	for i in GameConfig.PIECES_PER_SET:
		if not used_slots[i]:
			out.append(BlockShapes.cells(set[i]))
	return out

func has_any_move() -> bool:
	return board.any_placement_for_shapes(remaining_shapes())

## Apply a placement locally. Returns the full result dictionary or
## {ok=false, reason} when invalid.
func place(slot: int, anchor: Vector2i) -> Dictionary:
	if not slot_available(slot):
		return {"ok": false, "reason": "slot_unavailable"}
	if not board.can_place(slot_shape(slot), anchor):
		return {"ok": false, "reason": "collision"}

	var placed_set := set_index
	var shape_cells := slot_shape(slot)
	var shape_index := slot_shape_index(slot)
	var result := board.place(shape_cells, anchor, (shape_index % 7) + 1)
	var ev := ScoringConfig.score_placement(result["placed"].size(), result["lines"], combo)

	score += ev["gained"]
	combo = ev["combo"]
	best_combo = maxi(best_combo, combo)
	lines_cleared += result["lines"]
	blocks_placed += result["placed"].size()
	used_slots[slot] = true

	if used_slots.all(func(u): return u):
		set_index += 1
		used_slots = [false, false, false]
		set_renewed.emit(set_index)

	is_game_over = not has_any_move()

	var out := result.duplicate()
	out["ok"] = true
	out["gained"] = ev["gained"]
	out["combo"] = combo
	out["score"] = score
	out["shape_index"] = shape_index
	out["slot"] = slot
	out["anchor"] = anchor
	out["game_over"] = is_game_over
	out["set_index"] = set_index
	out["placed_set_index"] = placed_set
	placed.emit(out)
	if is_game_over:
		game_over.emit()
	return out

## Convert absolute board cells to an anchor for resync purposes.
static func anchor_of(abs_cells: Array) -> Vector2i:
	var min_x := 99
	var min_y := 99
	for cell in abs_cells:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
	return Vector2i(min_x, min_y)

## Resync from authoritative server state (reconnect or rejection).
func apply_server_state(board_cells: Array, p_score: int, p_combo: int, p_set_index: int, p_used: Array, p_game_over: bool) -> void:
	board.from_cell_array(board_cells)
	score = p_score
	combo = p_combo
	set_index = p_set_index
	used_slots = [false, false, false]
	for s in p_used:
		if int(s) >= 0 and int(s) < GameConfig.PIECES_PER_SET:
			used_slots[int(s)] = true
	is_game_over = p_game_over
