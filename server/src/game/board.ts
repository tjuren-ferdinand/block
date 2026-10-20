/**
 * 8x8 board logic shared (in behavior) with client/src/core/board_state.gd.
 * The board is stored as a flat array of 64 ints (0 = empty, >0 = color id).
 * Line-clear detection, scoring inputs and game-over checks live here and
 * must behave identically to the client implementation.
 */

import { Cell } from "./shapes";

export const BOARD_SIZE = 8;
export const CELL_COUNT = BOARD_SIZE * BOARD_SIZE;

export function createBoard(): Int8Array {
  return new Int8Array(CELL_COUNT);
}

export function inBounds(r: number, c: number): boolean {
  return r >= 0 && r < BOARD_SIZE && c >= 0 && c < BOARD_SIZE;
}

export function canPlace(board: Int8Array, cells: readonly Cell[], anchorR: number, anchorC: number): boolean {
  for (const [dr, dc] of cells) {
    const r = anchorR + dr;
    const cc = anchorC + dc;
    if (!inBounds(r, cc) || board[r * BOARD_SIZE + cc] !== 0) return false;
  }
  return true;
}

/**
 * Normalize an arbitrary set of absolute cells to offset form:
 * subtract min row and min col. Used to compare client-submitted
 * placements against the authoritative shape offsets.
 */
export function normalizeCells(cells: readonly Cell[]): Cell[] {
  let minR = Infinity;
  let minC = Infinity;
  for (const [r, c] of cells) {
    if (r < minR) minR = r;
    if (c < minC) minC = c;
  }
  return cells.map(([r, c]) => [r - minR, c - minC] as const);
}

/** True if two cell-offset sets contain the same cells (order-insensitive). */
export function sameCellSet(a: readonly Cell[], b: readonly Cell[]): boolean {
  if (a.length !== b.length) return false;
  const key = ([r, c]: Cell) => r * BOARD_SIZE + c;
  const set = new Set(a.map(key));
  for (const cell of b) {
    const k = key(cell);
    if (!set.has(k)) return false;
    set.delete(k);
  }
  return set.size === 0;
}

export interface PlacementResult {
  placedCells: Cell[];
  clearedCells: Cell[];
  linesCleared: number; // rows + columns cleared in one move
}

/**
 * Place `cells` (shape offsets) at anchor (anchorR, anchorC) with `colorId`.
 * Assumes canPlace() already returned true. Clears completed rows/columns.
 */
export function placePiece(
  board: Int8Array,
  cells: readonly Cell[],
  anchorR: number,
  anchorC: number,
  colorId: number
): PlacementResult {
  const placedCells: Cell[] = [];
  for (const [dr, dc] of cells) {
    const r = anchorR + dr;
    const cc = anchorC + dc;
    board[r * BOARD_SIZE + cc] = colorId;
    placedCells.push([r, cc]);
  }

  const rows = new Set<number>();
  const cols = new Set<number>();
  for (let r = 0; r < BOARD_SIZE; r++) {
    let full = true;
    for (let cIdx = 0; cIdx < BOARD_SIZE; cIdx++) {
      if (board[r * BOARD_SIZE + cIdx] === 0) {
        full = false;
        break;
      }
    }
    if (full) rows.add(r);
  }
  for (let cIdx = 0; cIdx < BOARD_SIZE; cIdx++) {
    let full = true;
    for (let r = 0; r < BOARD_SIZE; r++) {
      if (board[r * BOARD_SIZE + cIdx] === 0) {
        full = false;
        break;
      }
    }
    if (full) cols.add(cIdx);
  }

  const clearedCells: Cell[] = [];
  for (const r of rows) {
    for (let cIdx = 0; cIdx < BOARD_SIZE; cIdx++) {
      board[r * BOARD_SIZE + cIdx] = 0;
      clearedCells.push([r, cIdx]);
    }
  }
  for (const cIdx of cols) {
    for (let r = 0; r < BOARD_SIZE; r++) {
      if (board[r * BOARD_SIZE + cIdx] !== 0) {
        board[r * BOARD_SIZE + cIdx] = 0;
        clearedCells.push([r, cIdx]);
      }
    }
  }

  return {
    placedCells,
    clearedCells,
    linesCleared: rows.size + cols.size,
  };
}

/** Does the given shape fit anywhere on the board? */
export function anyPlacementForShape(board: Int8Array, cells: readonly Cell[]): boolean {
  let maxR = 0;
  let maxC = 0;
  for (const [dr, dc] of cells) {
    if (dr > maxR) maxR = dr;
    if (dc > maxC) maxC = dc;
  }
  for (let r = 0; r <= BOARD_SIZE - 1 - maxR; r++) {
    for (let cIdx = 0; cIdx <= BOARD_SIZE - 1 - maxC; cIdx++) {
      if (canPlace(board, cells, r, cIdx)) return true;
    }
  }
  return false;
}

/** Does ANY of the given shapes fit anywhere? (game-over check) */
export function anyPlacementForShapes(board: Int8Array, shapes: readonly Cell[][]): boolean {
  for (const cells of shapes) {
    if (anyPlacementForShape(board, cells)) return true;
  }
  return false;
}

/** Encode board occupancy as 8 row bitmasks for compact network transfer. */
export function boardToBitmask(board: Int8Array): number[] {
  const rows: number[] = new Array(BOARD_SIZE).fill(0);
  for (let r = 0; r < BOARD_SIZE; r++) {
    let bits = 0;
    for (let cIdx = 0; cIdx < BOARD_SIZE; cIdx++) {
      if (board[r * BOARD_SIZE + cIdx] !== 0) bits |= 1 << cIdx;
    }
    rows[r] = bits;
  }
  return rows;
}

/** Full cell grid for reconnect sync (0/1 occupancy + color not needed by opponent). */
export function boardToCellArray(board: Int8Array): number[] {
  return Array.from(board);
}

export function cellArrayToBoard(cells: number[]): Int8Array {
  const board = new Int8Array(CELL_COUNT);
  for (let i = 0; i < Math.min(cells.length, CELL_COUNT); i++) {
    board[i] = cells[i] > 0 ? Math.min(cells[i], 127) : 0;
  }
  return board;
}
