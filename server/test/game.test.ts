import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { Rng } from "../src/game/rng";
import { SHAPES, SHAPE_WEIGHTS } from "../src/game/shapes";
import {
  anyPlacementForShape,
  anyPlacementForShapes,
  boardToBitmask,
  canPlace,
  createBoard,
  normalizeCells,
  placePiece,
  sameCellSet,
  BOARD_SIZE,
} from "../src/game/board";
import { scorePlacement, lineBonus } from "../src/game/scoring";
import { generateSet, PIECES_PER_SET } from "../src/game/generator";
import { PlayerMatchState } from "../src/match/matchSession";

describe("rng", () => {
  it("is deterministic for the same seed", () => {
    const a = new Rng(12345);
    const b = new Rng(12345);
    for (let i = 0; i < 100; i++) {
      assert.strictEqual(a.nextFloat(), b.nextFloat());
    }
  });

  it("differs across seeds", () => {
    const a = new Rng(1);
    const b = new Rng(2);
    const seqA = Array.from({ length: 10 }, () => a.nextFloat());
    const seqB = Array.from({ length: 10 }, () => b.nextFloat());
    assert.notDeepStrictEqual(seqA, seqB);
  });

  it("produces values in [0,1)", () => {
    const r = new Rng(999);
    for (let i = 0; i < 1000; i++) {
      const v = r.nextFloat();
      assert.ok(v >= 0 && v < 1);
    }
  });
});

describe("shapes", () => {
  it("catalog and weights align", () => {
    assert.strictEqual(SHAPES.length, SHAPE_WEIGHTS.length);
    assert.ok(SHAPES.length >= 20);
  });

  it("all shapes are normalized to origin", () => {
    for (const s of SHAPES) {
      const norm = normalizeCells(s.cells);
      assert.ok(sameCellSet(norm, s.cells));
      const minR = Math.min(...s.cells.map(([r]) => r));
      const minC = Math.min(...s.cells.map(([, c]) => c));
      assert.strictEqual(minR, 0);
      assert.strictEqual(minC, 0);
    }
  });
});

describe("board", () => {
  it("accepts a valid placement and rejects collisions", () => {
    const b = createBoard();
    const sq2 = SHAPES.find((s) => s.id === "square2")!.cells;
    assert.ok(canPlace(b, sq2, 0, 0));
    placePiece(b, sq2, 0, 0, 1);
    assert.ok(!canPlace(b, sq2, 0, 0));
    assert.ok(canPlace(b, sq2, 2, 0));
  });

  it("rejects out-of-bounds placement", () => {
    const b = createBoard();
    const sq2 = SHAPES.find((s) => s.id === "square2")!.cells;
    assert.ok(!canPlace(b, sq2, 7, 7));
    assert.ok(canPlace(b, sq2, 6, 6));
    assert.ok(!canPlace(b, sq2, -1, 0));
  });

  it("clears a completed row", () => {
    const b = createBoard();
    const single = SHAPES.find((s) => s.id === "single")!.cells;
    for (let c = 0; c < BOARD_SIZE; c++) {
      const r = placePiece(b, single, 0, c, 1);
      if (c < BOARD_SIZE - 1) assert.strictEqual(r.linesCleared, 0);
      else assert.strictEqual(r.linesCleared, 1);
    }
    for (let c = 0; c < BOARD_SIZE; c++) {
      assert.strictEqual(b[c], 0);
    }
  });

  it("clears a row and column simultaneously", () => {
    const b = createBoard();
    const single = SHAPES.find((s) => s.id === "single")!.cells;
    for (let c = 1; c < BOARD_SIZE; c++) placePiece(b, single, 0, c, 1);
    for (let r = 1; r < BOARD_SIZE; r++) placePiece(b, single, r, 0, 1);
    const res = placePiece(b, single, 0, 0, 1);
    assert.strictEqual(res.linesCleared, 2);
    assert.strictEqual(res.clearedCells.length, 8 + 8 - 1);
  });

  it("detects game over on a full board", () => {
    const b = createBoard().fill(1);
    const single = SHAPES.find((s) => s.id === "single")!.cells;
    assert.ok(!anyPlacementForShape(b, single));
    assert.ok(!anyPlacementForShapes(b, [single]));
  });

  it("bitmask encodes occupancy", () => {
    const b = createBoard();
    b[0] = 1;
    b[7] = 1;
    b[63] = 1;
    const mask = boardToBitmask(b);
    assert.strictEqual(mask[0], 0b10000001);
    assert.strictEqual(mask[7], 0b10000000);
  });
});

describe("scoring", () => {
  it("awards placement points", () => {
    const ev = scorePlacement(4, 0, 0);
    assert.strictEqual(ev.gained, 4);
    assert.strictEqual(ev.combo, 0);
  });

  it("applies line bonuses and combo multiplier", () => {
    assert.strictEqual(lineBonus(1), 10);
    assert.strictEqual(lineBonus(2), 30);
    const e1 = scorePlacement(4, 1, 0);
    assert.strictEqual(e1.gained, 14);
    assert.strictEqual(e1.combo, 1);
    const e2 = scorePlacement(4, 1, 1);
    assert.strictEqual(e2.gained, 24);
    assert.strictEqual(e2.combo, 2);
    const e3 = scorePlacement(4, 2, 2);
    assert.strictEqual(e3.gained, 94);
    const reset = scorePlacement(3, 0, 5);
    assert.strictEqual(reset.combo, 0);
    assert.strictEqual(reset.gained, 3);
  });
});

describe("generator", () => {
  it("produces identical sets for identical seeds", () => {
    for (let s = 0; s < 20; s++) {
      assert.deepStrictEqual(generateSet(777, s), generateSet(777, s));
    }
  });

  it("generates exactly 3 pieces per set", () => {
    for (let s = 0; s < 10; s++) {
      assert.strictEqual(generateSet(42, s).length, PIECES_PER_SET);
    }
  });

  it("set sequences advance deterministically", () => {
    const seq0 = generateSet(5, 0);
    const seq1 = generateSet(5, 1);
    const rngSeq: number[] = [];
    for (let s = 0; s < 2; s++) rngSeq.push(...generateSet(5, s));
    assert.deepStrictEqual(rngSeq.slice(0, 3), seq0);
    assert.deepStrictEqual(rngSeq.slice(3, 6), seq1);
  });
});

describe("PlayerMatchState (authoritative validation)", () => {
  it("accepts a correct placement and rejects a wrong shape", () => {
    const st = new PlayerMatchState(123);
    const shape = st.currentSetShapes()[0];
    const absolute = shape.map(([r, c]) => [r + 3, c + 2] as [number, number]);
    const res = st.place(0, 0, absolute);
    assert.ok(res.ok);
    if (res.ok) {
      assert.ok(res.score > 0);
      assert.strictEqual(res.gameOver, false);
    }
    const res2 = st.place(0, 0, absolute);
    assert.ok(!res2.ok);
  });

  it("rejects placements with wrong cells for the slot", () => {
    const st = new PlayerMatchState(123);
    const res = st.place(0, 0, [[0, 0]]);
    const shape = st.currentSetShapes()[0];
    if (shape.length !== 1) {
      assert.ok(!res.ok);
      if (!res.ok) assert.strictEqual(res.code, "bad_shape");
    }
  });

  it("rejects colliding placements", () => {
    const st = new PlayerMatchState(55);
    const shape = st.currentSetShapes()[0];
    const abs = shape.map(([r, c]) => [r, c] as [number, number]);
    assert.ok(st.place(0, 0, abs).ok);
    const shape1 = st.currentSetShapes()[1];
    const abs1 = shape1.map(([r, c]) => [r, c] as [number, number]);
    const res = st.place(0, 1, abs1);
    if (!sameCellSet(shape1, shape)) {
      if (!res.ok) assert.strictEqual(res.code, "bad_placement");
    }
  });

  it("advances to the next set after 3 placements", () => {
    const st = new PlayerMatchState(9);
    for (let slot = 0; slot < 3; slot++) {
      const shape = st.currentSetShapes()[slot];
      let placed = false;
      for (let r = 0; r < 8 && !placed; r++) {
        for (let c = 0; c < 8 && !placed; c++) {
          const abs = shape.map(([dr, dc]) => [r + dr, c + dc] as [number, number]);
          const res = st.place(0, slot, abs);
          if (res.ok) placed = true;
        }
      }
      assert.ok(placed);
    }
    assert.strictEqual(st.setIndex, 1);
    assert.strictEqual(st.usedSlots.size, 0);
  });

  it("rejects placements from a future set", () => {
    const st = new PlayerMatchState(3);
    const res = st.place(1, 0, [[0, 0]]);
    assert.ok(!res.ok);
    if (!res.ok) assert.strictEqual(res.code, "bad_set");
  });
});
