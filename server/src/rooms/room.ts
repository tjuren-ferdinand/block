/**
 * Room: a lobby of (max) 2 players plus the match between them.
 * Handles match lifecycle: countdown start, placements, tick, game over,
 * match end, disconnect grace, rematch.
 */

import { config } from "../config";
import { PlayerMatchState } from "../match/matchSession";
import {
  MatchEndPayload,
  Msg,
  PlayerSummary,
  ReconnectStatePayload,
  StartMatchPayload,
} from "../protocol";
import { Cell, SHAPES } from "../game/shapes";
import { boardToBitmask } from "../game/board";
import { generateSet } from "../game/generator";

export interface SessionHandle {
  playerId: string;
  name: string;
  token: string;
  connected: boolean;
  send: (type: Msg, payload: unknown) => void;
}

interface RoomPlayer {
  session: SessionHandle;
  state: PlayerMatchState | null;
  rematchRequested: boolean;
  disconnectTimer: NodeJS.Timeout | null;
}

export type RoomPhase = "lobby" | "countdown" | "playing" | "ended";

export class Room {
  phase: RoomPhase = "lobby";
  matchId = "";
  seed = 0;
  startAtMs = 0;
  endsAtMs = 0;
  readonly players = new Map<string, RoomPlayer>(); // playerId -> player
  private tickTimer: NodeJS.Timeout | null = null;
  private endTimer: NodeJS.Timeout | null = null;
  private startTimer: NodeJS.Timeout | null = null;
  private matchCounter = 0;

  constructor(
    public readonly code: string,
    private readonly onEmpty: (code: string) => void
  ) {}

  get size(): number {
    return this.players.size;
  }

  playerSummaries(): PlayerSummary[] {
    return [...this.players.values()].map((p) => ({
      playerId: p.session.playerId,
      name: p.session.name,
      connected: p.session.connected,
    }));
  }

  addPlayer(session: SessionHandle): { ok: boolean; error?: string } {
    if (this.players.has(session.playerId)) {
      // same player rejoining the lobby/match
      this.attachSession(session);
      return { ok: true };
    }
    if (this.players.size >= config.maxPlayersPerRoom) {
      return { ok: false, error: "Room is full" };
    }
    if (this.phase !== "lobby") {
      return { ok: false, error: "Match already in progress" };
    }
    this.players.set(session.playerId, {
      session,
      state: null,
      rematchRequested: false,
      disconnectTimer: null,
    });
    this.broadcast(Msg.PLAYER_JOINED, { players: this.playerSummaries() });

    if (this.players.size === config.maxPlayersPerRoom) {
      this.beginMatch();
    }
    return { ok: true };
  }

  removePlayer(playerId: string): void {
    const p = this.players.get(playerId);
    if (p?.disconnectTimer) clearTimeout(p.disconnectTimer);
    this.players.delete(playerId);
    this.broadcast(Msg.PLAYER_LEFT, { playerId, players: this.playerSummaries() });
    if (this.players.size === 0) {
      this.dispose();
      this.onEmpty(this.code);
    }
  }

  /** Rebind an existing player slot to a fresh socket/session. */
  attachSession(session: SessionHandle): boolean {
    const p = this.players.get(session.playerId);
    if (!p) return false;
    if (p.disconnectTimer) {
      clearTimeout(p.disconnectTimer);
      p.disconnectTimer = null;
    }
    p.session = session;
    p.session.connected = true;
    this.broadcast(Msg.OPPONENT_RECONNECTED, { playerId: session.playerId }, session.playerId);
    return true;
  }

  // ---------------- match lifecycle ----------------

  beginMatch(): void {
    this.matchCounter++;
    this.phase = "countdown";
    this.matchId = `${this.code}-${this.matchCounter}-${Date.now().toString(36)}`;
    this.seed = (Math.random() * 0xffffffff) >>> 0;
    this.startAtMs = Date.now() + config.countdownMs;
    this.endsAtMs = this.startAtMs + config.matchDurationMs;

    for (const p of this.players.values()) {
      p.state = new PlayerMatchState(this.seed);
      p.rematchRequested = false;
    }

    const payload: StartMatchPayload = {
      matchId: this.matchId,
      seed: this.seed,
      startAtMs: this.startAtMs,
      durationMs: config.matchDurationMs,
      serverNowMs: Date.now(),
      players: this.playerSummaries(),
    };
    this.broadcast(Msg.START_MATCH, payload);

    this.startTimer = setTimeout(() => {
      this.phase = "playing";
      this.startTicking();
    }, config.countdownMs);
  }

  private startTicking(): void {
    this.tickTimer = setInterval(() => {
      const remaining = Math.max(0, this.endsAtMs - Date.now());
      this.broadcast(Msg.TICK, { remainingMs: remaining });
    }, config.tickIntervalMs);
    this.endTimer = setTimeout(() => this.finishMatch("timer"), config.matchDurationMs);
  }

  /** Handle a validated placement submission from a player. */
  handlePlace(playerId: string, setIndex: number, slotIndex: number, cells: Cell[]): void {
    if (this.phase !== "playing") {
      this.sendTo(playerId, Msg.PLACE_REJECTED, { code: "not_playing", message: "Match is not active" });
      return;
    }
    const p = this.players.get(playerId);
    if (!p || !p.state) return;

    const res = p.state.place(setIndex, slotIndex, cells);
    if (!res.ok) {
      this.sendTo(playerId, Msg.PLACE_REJECTED, { code: res.code, message: res.message });
      // Tell the truth: send the authoritative state so the client can resync.
      this.sendTo(playerId, Msg.BOARD_UPDATE, this.boardUpdateFor(playerId));
      return;
    }

    this.sendTo(playerId, Msg.PLACE_ACCEPTED, {
      setIndex,
      slotIndex,
      gained: res.gained,
      score: res.score,
      combo: res.combo,
      linesCleared: res.linesCleared,
      clearedCells: res.clearedCells,
      board: res.board,
      nextSetIndex: res.nextSetIndex,
      gameOver: res.gameOver,
    });
    this.sendTo(playerId, Msg.SCORE_UPDATE, { score: res.score, combo: res.combo, gained: res.gained });
    if (res.combo >= 2) {
      this.sendTo(playerId, Msg.COMBO_UPDATE, { combo: res.combo });
    }

    const update = this.boardUpdateFor(playerId);
    for (const other of this.players.keys()) {
      if (other !== playerId) this.sendTo(other, Msg.BOARD_UPDATE, update);
    }

    if (res.gameOver) {
      this.handleGameOver(playerId);
    }
  }

  private boardUpdateFor(playerId: string) {
    const p = this.players.get(playerId)!;
    return {
      playerId,
      board: boardToBitmask(p.state!.board),
      score: p.state!.score,
      combo: p.state!.combo,
      linesClearedTotal: p.state!.linesCleared,
      blocksPlacedTotal: p.state!.blocksPlaced,
    };
  }

  /** Client-declared game over — verified server-side. */
  handleGameOverClaim(playerId: string): void {
    const p = this.players.get(playerId);
    if (!p || !p.state || this.phase !== "playing") return;
    if (p.state.hasAnyMove()) {
      this.sendTo(playerId, Msg.ERROR, { code: "not_game_over", message: "Valid moves remain" });
      return;
    }
    p.state.gameOver = true;
    this.handleGameOver(playerId);
  }

  private handleGameOver(playerId: string): void {
    const p = this.players.get(playerId);
    if (!p || !p.state) return;
    for (const other of this.players.keys()) {
      if (other !== playerId) {
        this.sendTo(other, Msg.OPPONENT_GAME_OVER, { playerId, score: p.state.score });
      }
    }
    this.maybeFinishEarly();
  }

  private maybeFinishEarly(): void {
    if (this.phase !== "playing") return;
    const all = [...this.players.values()];
    if (all.length > 0 && all.every((pl) => pl.state?.gameOver)) {
      this.finishMatch("both_game_over");
    }
  }

  handleDisconnect(playerId: string): void {
    const p = this.players.get(playerId);
    if (!p) return;
    p.session.connected = false;

    if (this.phase === "playing" || this.phase === "countdown") {
      this.broadcast(Msg.OPPONENT_DISCONNECTED, { playerId, graceMs: config.reconnectGraceMs }, playerId);
      p.disconnectTimer = setTimeout(() => {
        // Grace expired: the still-connected player wins.
        if (this.phase === "playing" || this.phase === "countdown") {
          this.finishMatch("disconnect", playerId);
        }
      }, config.reconnectGraceMs);
    } else if (this.phase === "lobby") {
      this.removePlayer(playerId);
    } else {
      // ended: keep slot for rematch, but eventually the room empties via WS close cleanup
      p.disconnectTimer = setTimeout(() => this.removePlayer(playerId), 60_000);
    }
  }

  handleRematch(playerId: string): void {
    if (this.phase !== "ended") return;
    const p = this.players.get(playerId);
    if (!p) return;
    p.rematchRequested = true;
    const all = [...this.players.values()];
    const waiting = all.filter((pl) => !pl.rematchRequested && pl.session.connected).length;
    this.broadcast(Msg.REMATCH_STATUS, {
      requestedBy: playerId,
      waitingFor: waiting,
      accepted: [...this.players.values()].filter((pl) => pl.rematchRequested).map((pl) => pl.session.playerId),
    });
    if (this.players.size === config.maxPlayersPerRoom && waiting === 0) {
      this.beginMatch();
    }
  }

  /** Build the full resync payload for a reconnecting player. */
  buildReconnectState(playerId: string): ReconnectStatePayload | null {
    const p = this.players.get(playerId);
    if (!p || !p.state) return null;
    const opponentEntry = [...this.players.entries()].find(([id]) => id !== playerId);
    const opp = opponentEntry?.[1];
    return {
      matchId: this.matchId,
      seed: this.seed,
      remainingMs: Math.max(0, this.endsAtMs - Date.now()),
      durationMs: config.matchDurationMs,
      startAtMs: this.startAtMs,
      serverNowMs: Date.now(),
      you: {
        score: p.state.score,
        combo: p.state.combo,
        setIndex: p.state.setIndex,
        usedSlots: [...p.state.usedSlots],
        boardCells: p.state.toCellArray(),
        gameOver: p.state.gameOver,
      },
      opponent: opp
        ? {
            playerId: opp.session.playerId,
            name: opp.session.name,
            score: opp.state?.score ?? 0,
            board: opp.state ? boardToBitmask(opp.state.board) : new Array(8).fill(0),
            gameOver: opp.state?.gameOver ?? false,
            connected: opp.session.connected,
          }
        : {
            playerId: "",
            name: "",
            score: 0,
            board: new Array(8).fill(0),
            gameOver: false,
            connected: false,
          },
      players: this.playerSummaries(),
    };
  }

  getPlayerByToken(token: string): RoomPlayer | undefined {
    return [...this.players.values()].find((p) => p.session.token === token);
  }

  private finishMatch(reason: MatchEndPayload["reason"], disconnectedPlayerId?: string): void {
    if (this.phase === "ended") return;
    this.phase = "ended";
    if (this.tickTimer) clearInterval(this.tickTimer);
    if (this.endTimer) clearTimeout(this.endTimer);
    if (this.startTimer) clearTimeout(this.startTimer);
    this.tickTimer = this.endTimer = this.startTimer = null;

    const entries = [...this.players.values()];
    let winnerId: string | null = null;
    if (reason === "disconnect" && disconnectedPlayerId) {
      const other = entries.find((p) => p.session.playerId !== disconnectedPlayerId);
      winnerId = other?.session.playerId ?? null;
    } else {
      const scores = entries.map((p) => p.state?.score ?? 0);
      const max = Math.max(...scores);
      const winners = scores.filter((s) => s === max);
      if (winners.length === 1) {
        winnerId = entries[scores.indexOf(max)].session.playerId;
      }
    }

    const payload: MatchEndPayload = {
      winnerId,
      reason,
      players: entries.map((p) => ({
        playerId: p.session.playerId,
        name: p.session.name,
        score: p.state?.score ?? 0,
        linesCleared: p.state?.linesCleared ?? 0,
        blocksPlaced: p.state?.blocksPlaced ?? 0,
        bestCombo: p.state?.bestCombo ?? 0,
        gameOver: p.state?.gameOver ?? false,
      })),
    };
    this.broadcast(Msg.MATCH_END, payload);
  }

  // ---------------- util ----------------

  sendTo(playerId: string, type: Msg, payload: unknown): void {
    const p = this.players.get(playerId);
    if (p?.session.connected) p.session.send(type, payload);
  }

  broadcast(type: Msg, payload: unknown, exceptPlayerId?: string): void {
    for (const p of this.players.values()) {
      if (p.session.playerId === exceptPlayerId) continue;
      if (p.session.connected) p.session.send(type, payload);
    }
  }

  dispose(): void {
    if (this.tickTimer) clearInterval(this.tickTimer);
    if (this.endTimer) clearTimeout(this.endTimer);
    if (this.startTimer) clearTimeout(this.startTimer);
    for (const p of this.players.values()) {
      if (p.disconnectTimer) clearTimeout(p.disconnectTimer);
    }
    this.players.clear();
  }

  /** Peek: current set shapes for a player (used by tests/debug). */
  debugSetFor(playerId: string): string[] {
    const p = this.players.get(playerId);
    if (!p?.state) return [];
    return generateSet(this.seed, p.state.setIndex).map((i) => SHAPES[i].id);
  }
}
