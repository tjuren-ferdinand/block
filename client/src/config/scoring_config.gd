class_name ScoringConfig
extends RefCounted

## Scoring balance constants. MUST mirror server/src/game/scoring.ts.

const POINTS_PER_BLOCK := 1

# Bonus for clearing N lines in one placement (index = lines).
const LINE_CLEAR_BONUS: Array[int] = [0, 10, 30, 60, 100, 160, 230, 310, 400]
const EXTRA_PER_EXTRA_LINE := 100

static func line_bonus(lines: int) -> int:
	if lines <= 0:
		return 0
	if lines < LINE_CLEAR_BONUS.size():
		return LINE_CLEAR_BONUS[lines]
	return LINE_CLEAR_BONUS[LINE_CLEAR_BONUS.size() - 1] + (lines - LINE_CLEAR_BONUS.size() + 1) * EXTRA_PER_EXTRA_LINE

## streak = combo value BEFORE this placement. Clearing increments it,
## not clearing resets it. Bonus is multiplied by the new streak.
static func score_placement(blocks_placed: int, lines_cleared: int, streak: int) -> Dictionary:
	var gained := blocks_placed * POINTS_PER_BLOCK
	if lines_cleared <= 0:
		return {"blocks_placed": blocks_placed, "lines_cleared": 0, "combo": 0, "gained": gained}
	var combo := streak + 1
	return {
		"blocks_placed": blocks_placed,
		"lines_cleared": lines_cleared,
		"combo": combo,
		"gained": gained + line_bonus(lines_cleared) * combo,
	}
