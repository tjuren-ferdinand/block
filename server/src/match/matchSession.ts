/**
 * Authoritative per-player game state inside a match.
 *
 * The server owns the board, score, combo and piece cursor for each
 * player. Clients submit placements; the server validates them against
 * the deterministic piece sequence (seed + setIndex + slotIndex) and
 * its own board, then derives the score itself. Client-reported scores
 * are never trusted.
 */

import {
  anyPlacementForShapes,
  boardToBitmask,
  boardToCellArray,
  canPlace,
  createBoard,
  normalizeCells,
  placePiece,
  sameCellSet,
} from "../game/board";
import { generateSet, PIECES_PER_SET } from "../game/generator";
import { scorePlacement } from "../game/scoring";
import { Cell, SHAPES } from "../game/shapes";

export interface PlayerStats {
  score: number;
  combo: number;
  bestCombo: number;
  linesCleared: number;
  blocksPlaced: number;
}

export type PlaceResult =
  | {
      ok: true;
      gained: number;
      score: number;
      combo: number;
      linesCleared: number;
      clearedCells: { r: number; c: number }[];
      board: number[];
      nextSetIndex: number;
      gameOver: boolean;
    }
  | { ok: false; code: string; message: string };

export class PlayerMatchState {
  board = createBoard();
  score = 0;
  combo = 0;
  bestCombo = 0;
  linesCleared = 0;
  blocksPlaced = 0;
  setIndex = 0;
  usedSlots = new Set<number>();
  gameOver = false;
  placementCount = 0;

  constructor(private readonly seed: number) {}

  currentSetShapes(): Cell[][] {
    return generateSet(this.seed, this.setIndex).map((i) => SHAPES[i].cells as Cell[]);
  }

  remainingShapes(): Cell[][] {
    const shapes = this.currentSetShapes();
    const out: Cell[][] = [];
    for (let i = 0; i < PIECES_PER_SET; i++) {
      if (!this.usedSlots.has(i)) out.push(shapes[i]);
    }
    return out;
  }

  hasAnyMove(): boolean {
    return anyPlacementForShapes(this.board, this.remainingShapes());
  }

  /**
   * Validate and apply a client-submitted placement.
   * cells are absolute board coordinates covered by the piece.
   */
  place(setIndex: number, slotIndex: number, cells: Cell[]): PlaceResult {
    if (this.gameOver) return { ok: false, code: "game_over", message: "Player is already out" };
    if (setIndex !== this.setIndex) {
      return { ok: false, code: "bad_set", message: `Expected set ${this.setIndex}, got ${setIndex}` };
    }
    if (slotIndex < 0 || slotIndex >= PIECES_PER_SET) {
      return { ok: false, code: "bad_slot", message: "Invalid slot index" };
    }
    if (this.usedSlots.has(slotIndex)) {
      return { ok: false, code: "slot_used", message: "Piece already used" };
    }

    const shapeIndex = generateSet(this.seed, setIndex)[slotIndex];
    const shape = SHAPES[shapeIndex];
    const normalized = normalizeCells(cells);
    if (!sameCellSet(normalized, shape.cells as Cell[])) {
      return { ok: false, code: "bad_shape", message: "Cells do not match expected piece shape" };
    }

    // Anchor = min row/col of submitted cells (cells are normalized offsets
    // translated to the board position).
    let minR = Infinity;
    let minC = Infinity;
    for (const [r, c] of cells) {
      if (r < minR) minR = r;
      if (c < minC) minC = c;
    }
    if (!canPlace(this.board, shape.cells as Cell[], minR, minC)) {
      return { ok: false, code: "bad_placement", message: "Placement collides or is out of bounds" };
    }

    const result = placePiece(this.board, shape.cells as Cell[], minR, minC, (slotIndex % 7) + 1);
    const ev = scorePlacement(result.placedCells.length, result.linesCleared, this.combo);

    this.score += ev.gained;
    this.combo = ev.combo;
    this.bestCombo = Math.max(this.bestCombo, ev.combo);
    this.linesCleared += result.linesCleared;
    this.blocksPlaced += result.placedCells.length;
    this.usedSlots.add(slotIndex);
    this.placementCount++;

    if (this.usedSlots.size === PIECES_PER_SET) {
      this.setIndex++;
      this.usedSlots.clear();
    }

    this.gameOver = !this.hasAnyMove();

    return {
      ok: true,
      gained: ev.gained,
      score: this.score,
      combo: this.combo,
      linesCleared: result.linesCleared,
      clearedCells: result.clearedCells.map(([r, c]) => ({ r, c })),
      board: boardToBitmask(this.board),
      nextSetIndex: this.setIndex,
      gameOver: this.gameOver,
    };
  }

  stats(): PlayerStats {
    return {
      score: this.score,
      combo: this.combo,
      bestCombo: this.bestCombo,
      linesCleared: this.linesCleared,
      blocksPlaced: this.blocksPlaced,
    };
  }

  toCellArray(): number[] {
    return boardToCellArray(this.board);
  }
}
