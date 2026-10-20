/**
 * Piece shape catalog shared with the Godot client.
 * MUST stay in identical order/content as client/src/core/block_shapes.gd.
 * Cells are [row, col] offsets normalized so min row = min col = 0.
 */

export type Cell = readonly [number, number];

export interface ShapeDef {
  readonly id: string;
  readonly cells: readonly Cell[];
}

const c = (...pairs: number[][]): Cell[] => pairs.map((p) => [p[0], p[1]] as const);

export const SHAPES: readonly ShapeDef[] = [
  { id: "single",    cells: c([0, 0]) },
  { id: "domino_h",  cells: c([0, 0], [0, 1]) },
  { id: "domino_v",  cells: c([0, 0], [1, 0]) },
  { id: "tri_h",     cells: c([0, 0], [0, 1], [0, 2]) },
  { id: "tri_v",     cells: c([0, 0], [1, 0], [2, 0]) },
  { id: "line4_h",   cells: c([0, 0], [0, 1], [0, 2], [0, 3]) },
  { id: "line4_v",   cells: c([0, 0], [1, 0], [2, 0], [3, 0]) },
  { id: "line5_h",   cells: c([0, 0], [0, 1], [0, 2], [0, 3], [0, 4]) },
  { id: "line5_v",   cells: c([0, 0], [1, 0], [2, 0], [3, 0], [4, 0]) },
  { id: "square2",   cells: c([0, 0], [0, 1], [1, 0], [1, 1]) },
  { id: "square3",   cells: c([0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2], [2, 0], [2, 1], [2, 2]) },
  { id: "corner_tl", cells: c([0, 0], [0, 1], [1, 0]) },
  { id: "corner_tr", cells: c([0, 0], [0, 1], [1, 1]) },
  { id: "corner_bl", cells: c([0, 0], [1, 0], [1, 1]) },
  { id: "corner_br", cells: c([0, 1], [1, 0], [1, 1]) },
  { id: "l_big_a",   cells: c([0, 0], [1, 0], [2, 0], [2, 1]) },
  { id: "l_big_b",   cells: c([0, 1], [1, 1], [2, 0], [2, 1]) },
  { id: "l_big_c",   cells: c([0, 0], [0, 1], [1, 0], [2, 0]) },
  { id: "l_big_d",   cells: c([0, 0], [0, 1], [1, 1], [2, 1]) },
  { id: "t_up",      cells: c([0, 0], [0, 1], [0, 2], [1, 1]) },
  { id: "t_down",    cells: c([0, 1], [1, 0], [1, 1], [1, 2]) },
  { id: "s_h",       cells: c([0, 1], [0, 2], [1, 0], [1, 1]) },
  { id: "z_h",       cells: c([0, 0], [0, 1], [1, 1], [1, 2]) },
  { id: "rect_2x3",  cells: c([0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2]) },
  { id: "plus",      cells: c([0, 1], [1, 0], [1, 1], [1, 2], [2, 1]) },
  { id: "u_shape",   cells: c([0, 0], [0, 2], [1, 0], [1, 1], [1, 2]) },
] as const;

/**
 * Relative spawn weights per shape index (mirrored in the client).
 * Simple pieces are more common; large pieces are rarer.
 */
export const SHAPE_WEIGHTS: readonly number[] = [
  8,   // single
  10,  // domino_h
  10,  // domino_v
  9,   // tri_h
  9,   // tri_v
  7,   // line4_h
  7,   // line4_v
  5,   // line5_h
  5,   // line5_v
  9,   // square2
  4,   // square3
  6,   // corner_tl
  6,   // corner_tr
  6,   // corner_bl
  6,   // corner_br
  6,   // l_big_a
  6,   // l_big_b
  6,   // l_big_c
  6,   // l_big_d
  6,   // t_up
  6,   // t_down
  5,   // s_h
  5,   // z_h
  4,   // rect_2x3
  3,   // plus
  3,   // u_shape
];

export const SHAPE_COUNT = SHAPES.length;

export function shapeByIndex(index: number): ShapeDef | null {
  if (!Number.isInteger(index) || index < 0 || index >= SHAPES.length) return null;
  return SHAPES[index];
}
