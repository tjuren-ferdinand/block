/**
 * Deterministic piece-set generator shared with the client
 * (client/src/core/piece_generator.gd).
 *
 * Given a match seed, piece sets are produced in groups of 3 by a
 * weighted pick over SHAPES. The same seed + set index always yields
 * the same set on both clients and on the server.
 */

import { Rng } from "./rng";
import { SHAPES, SHAPE_WEIGHTS, ShapeDef } from "./shapes";

export const PIECES_PER_SET = 3;

const TOTAL_WEIGHT = SHAPE_WEIGHTS.reduce((a, b) => a + b, 0);

/** Pick one shape index using the rng. Must mirror client exactly. */
function pickShapeIndex(rng: Rng): number {
  const roll = rng.nextFloat() * TOTAL_WEIGHT;
  let acc = 0;
  for (let i = 0; i < SHAPE_WEIGHTS.length; i++) {
    acc += SHAPE_WEIGHTS[i];
    if (roll < acc) return i;
  }
  return SHAPE_WEIGHTS.length - 1; // unreachable, safety
}

/**
 * Generate the shape indices for piece set `setIndex` under `seed`.
 * Regenerated from scratch each call — cheap and keeps server stateless
 * about sequence position.
 */
export function generateSet(seed: number, setIndex: number): number[] {
  const rng = new Rng(seed);
  const totalToSkip = setIndex * PIECES_PER_SET;
  for (let i = 0; i < totalToSkip; i++) {
    pickShapeIndex(rng);
  }
  return [pickShapeIndex(rng), pickShapeIndex(rng), pickShapeIndex(rng)];
}

export function shapesForSet(seed: number, setIndex: number): ShapeDef[] {
  return generateSet(seed, setIndex).map((i) => SHAPES[i]);
}
