/**
 * Deterministic RNG shared with the Godot client.
 * MUST produce identical output to client/src/core/rng.gd (mulberry32).
 * Do not change this algorithm without updating the client.
 */
export class Rng {
  private state: number;

  constructor(seed: number) {
    this.state = seed >>> 0;
  }

  /** Returns a float in [0, 1). */
  nextFloat(): number {
    this.state = (this.state + 0x6d2b79f5) >>> 0;
    let t = this.state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  /** Returns an integer in [0, n). */
  nextInt(n: number): number {
    return Math.floor(this.nextFloat() * n);
  }
}
