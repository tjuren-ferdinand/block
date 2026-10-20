class_name PieceGenerator
extends RefCounted

## Deterministic piece-set generator — MUST mirror
## server/src/game/generator.ts exactly.

const PER_SET := GameConfig.PIECES_PER_SET

static var _total_weight := -1

static func _pick_index(rng: BDRng) -> int:
	if _total_weight < 0:
		_total_weight = 0
		for w in BlockShapes.SHAPE_WEIGHTS:
			_total_weight += w
	var roll := rng.next_float() * _total_weight
	var acc := 0.0
	for i in BlockShapes.SHAPE_WEIGHTS.size():
		acc += BlockShapes.SHAPE_WEIGHTS[i]
		if roll < acc:
			return i
	return BlockShapes.SHAPE_WEIGHTS.size() - 1

## Returns Array[int] of 3 shape indices for the given seed + set index.
static func generate_set(seed: int, set_index: int) -> Array[int]:
	var rng := BDRng.new(seed)
	for i in set_index * PER_SET:
		_pick_index(rng)
	return [_pick_index(rng), _pick_index(rng), _pick_index(rng)]
