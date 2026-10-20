/**
 * Scoring rules shared with the client (client/src/core/scoring.gd).
 * All balance constants live here — mirror changes in the client config.
 */

/** Points per placed block cell. */
export const POINTS_PER_BLOCK = 1;

/**
 * Bonus for clearing N lines (rows + columns) in a single placement.
 * Index = number of lines. Values beyond the table add EXTRA_PER_EXTRA_LINE.
 */
export const LINE_CLEAR_BONUS: readonly number[] = [
  0,    // 0 lines (unused)
  10,   // 1 line
  30,   // 2 lines
  60,   // 3 lines
  100,  // 4 lines
  160,  // 5 lines
  230,  // 6 lines
  310,  // 7 lines
  400,  // 8+ lines
];

export const EXTRA_PER_EXTRA_LINE = 100;

export function lineBonus(lines: number): number {
  if (lines <= 0) return 0;
  if (lines < LINE_CLEAR_BONUS.length) return LINE_CLEAR_BONUS[lines];
  return LINE_CLEAR_BONUS[LINE_CLEAR_BONUS.length - 1] + (lines - LINE_CLEAR_BONUS.length + 1) * EXTRA_PER_EXTRA_LINE;
}

export interface ScoreEvent {
  blocksPlaced: number;
  linesCleared: number;
  /** combo streak AFTER this placement (0 if no clear) */
  combo: number;
  /** total points awarded by this placement */
  gained: number;
}

/**
 * Apply scoring for a placement.
 * comboStreak = the streak value BEFORE this placement.
 * A placement that clears at least one line increments the streak;
 * a placement that clears nothing resets it to 0.
 * The line-clear bonus is multiplied by the new streak value.
 */
export function scorePlacement(blocksPlaced: number, linesCleared: number, comboStreak: number): ScoreEvent {
  const gained = blocksPlaced * POINTS_PER_BLOCK;
  if (linesCleared <= 0) {
    return { blocksPlaced, linesCleared: 0, combo: 0, gained };
  }
  const combo = comboStreak + 1;
  const bonus = lineBonus(linesCleared) * combo;
  return { blocksPlaced, linesCleared, combo, gained: gained + bonus };
}
