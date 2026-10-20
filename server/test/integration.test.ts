/**
 * End-to-end test: spins up the real server on a random port and plays a
 * full match between two WebSocket clients — room creation, join, start,
 * validated placements, score sync, disconnect/reconnect.
 */

import { describe, it, before, after } from "node:test";
import assert from "node:assert/strict";
import WebSocket from "ws";
import { GameServer } from "../src/net/wsServer";
import { Msg, WireMessage } from "../src/protocol";
import { generateSet } from "../src/game/generator";
import { SHAPES } from "../src/game/shapes";

const PORT = 18901;

class TestClient {
  ws: WebSocket;
  inbox: WireMessage[] = [];
  private waiters: { type: string; resolve: (m: WireMessage) => void }[] = [];
  playerId: string;
  token = "";

  constructor(playerId: string, private name: string) {
    this.playerId = playerId;
    this.ws = new WebSocket(`ws://127.0.0.1:${PORT}`);
    this.ws.on("message", (d) => {
      const m = JSON.parse(d.toString()) as WireMessage;
      const idx = this.waiters.findIndex((w) => w.type === m.type);
      if (idx >= 0) {
        const [w] = this.waiters.splice(idx, 1);
        w.resolve(m);
      } else {
        this.inbox.push(m);
      }
    });
  }

  open(): Promise<void> {
    return new Promise((res) => this.ws.on("open", res));
  }

  send(type: Msg, payload: unknown = {}): void {
    this.ws.send(JSON.stringify({ type, payload }));
  }

  waitFor(type: string, timeoutMs = 5000): Promise<WireMessage> {
    const existing = this.inbox.findIndex((m) => m.type === type);
    if (existing >= 0) {
      const [m] = this.inbox.splice(existing, 1);
      return Promise.resolve(m);
    }
    return new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error(`timeout waiting for ${type}`)), timeoutMs);
      this.waiters.push({
        type,
        resolve: (m) => {
          clearTimeout(t);
          resolve(m);
        },
      });
    });
  }

  connect(name?: string): Promise<WireMessage> {
    this.send(Msg.CONNECT, { playerId: this.playerId, name: name ?? this.name });
    return this.waitFor(Msg.CONNECTED);
  }

  close(): void {
    this.ws.close();
  }
}

let server: GameServer;

before(() => {
  server = new GameServer(PORT, "127.0.0.1");
});

after(() => {
  server.close();
});

describe("e2e match", () => {
  it("runs a complete 2-player match flow", async () => {
    const a = new TestClient("p-A", "Alice");
    const b = new TestClient("p-B", "Bob");
    await a.open();
    await b.open();

    const connA = await a.connect();
    const connB = await b.connect();
    a.token = (connA.payload as { token: string }).token;
    b.token = (connB.payload as { token: string }).token;
    assert.ok(a.token);

    a.send(Msg.CREATE_ROOM);
    const created = await a.waitFor(Msg.ROOM_CREATED);
    const roomCode = (created.payload as { roomCode: string }).roomCode;
    assert.match(roomCode, /^\d{6}$/);

    b.send(Msg.JOIN_ROOM, { roomCode });
    const joined = await b.waitFor(Msg.ROOM_JOINED);
    assert.strictEqual((joined.payload as { roomCode: string }).roomCode, roomCode);
    await a.waitFor(Msg.PLAYER_JOINED);

    const [startA, startB] = await Promise.all([a.waitFor(Msg.START_MATCH), b.waitFor(Msg.START_MATCH)]);
    const seedA = (startA.payload as { seed: number }).seed;
    const seedB = (startB.payload as { seed: number }).seed;
    const matchId = (startA.payload as { matchId: string }).matchId;
    assert.strictEqual(seedA, seedB);
    assert.ok(matchId);

    // Wait for countdown to end server-side (config.countdownMs = 3200 default)
    await new Promise((r) => setTimeout(r, 3400));

    // Player A places the first piece of set 0 at (0,0)
    const set0 = generateSet(seedA, 0);
    const shape0 = SHAPES[set0[0]];
    const absCells = shape0.cells.map(([r, c]) => ({ r, c }));
    a.send(Msg.PLACE_PIECE, { setIndex: 0, slotIndex: 0, cells: absCells });
    const accepted = await a.waitFor(Msg.PLACE_ACCEPTED);
    const accP = accepted.payload as { score: number; board: number[] };
    assert.ok(accP.score > 0);
    assert.strictEqual(accP.board.length, 8);

    // B should see A's board update
    const upd = await b.waitFor(Msg.BOARD_UPDATE);
    const updP = upd.payload as { playerId: string; score: number };
    assert.strictEqual(updP.playerId, "p-A");
    assert.strictEqual(updP.score, accP.score);

    // Invalid placement rejected (slot already used)
    a.send(Msg.PLACE_PIECE, { setIndex: 0, slotIndex: 0, cells: [{ r: 5, c: 5 }] });
    const rejected = await a.waitFor(Msg.PLACE_REJECTED);
    assert.ok(rejected);

    // Malformed message handled gracefully
    a.ws.send("not json{{{");
    const err = await a.waitFor(Msg.ERROR);
    assert.strictEqual((err.payload as { code: string }).code, "bad_message");

    // B disconnects; A should be told and given a grace window.
    b.ws.terminate();
    const disc = await a.waitFor(Msg.OPPONENT_DISCONNECTED);
    assert.strictEqual((disc.payload as { playerId: string }).playerId, "p-B");

    // Reconnect B within grace using its token
    const b2 = new TestClient("p-B", "Bob");
    await b2.open();
    b2.send(Msg.CONNECT, { playerId: "p-B", name: "Bob", token: b.token, matchId });
    const connB2 = await b2.waitFor(Msg.CONNECTED);
    assert.strictEqual((connB2.payload as { rejoined: boolean }).rejoined, true);
    const state = await b2.waitFor(Msg.RECONNECT_STATE);
    const st = state.payload as { seed: number; matchId: string; you: { score: number } };
    assert.strictEqual(st.seed, seedA);
    assert.strictEqual(st.matchId, matchId);

    a.close();
    b2.close();
  });

  it("rejects bad room codes", async () => {
    const c = new TestClient("p-C", "Carol");
    await c.open();
    await c.connect();
    c.send(Msg.JOIN_ROOM, { roomCode: "000000" });
    const e = await c.waitFor(Msg.ERROR);
    assert.strictEqual((e.payload as { code: string }).code, "room_not_found");
    c.send(Msg.JOIN_ROOM, { roomCode: "abc" });
    const e2 = await c.waitFor(Msg.ERROR);
    assert.strictEqual((e2.payload as { code: string }).code, "bad_code");
    c.close();
  });
});
