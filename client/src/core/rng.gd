class_name BDRng
extends RefCounted

## Deterministic RNG — MUST produce identical output to server/src/game/rng.ts
## (mulberry32). Do not change without updating the server.

var state: int

func _init(seed: int) -> void:
	state = seed & 0xFFFFFFFF

func next_float() -> float:
	state = (state + 0x6D2B79F5) & 0xFFFFFFFF
	var t: int = state
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

func next_int(n: int) -> int:
	return int(floor(next_float() * n))

func _imul(a: int, b: int) -> int:
	return (a * b) & 0xFFFFFFFF
