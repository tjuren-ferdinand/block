/**
 * Wire protocol for Block Duel. JSON messages of the form:
 *   { "type": "<MSG>", "payload": { ... } }
 *
 * All message types are enumerated here — do not scatter raw strings.
 * The client mirrors these in client/src/net/protocol.gd.
 */

export enum Msg {
  // client -> server
  CONNECT = "CONNECT",
  CREATE_ROOM = "CREATE_ROOM",
  JOIN_ROOM = "JOIN_ROOM",
  LEAVE_ROOM = "LEAVE_ROOM",
  PLACE_PIECE = "PLACE_PIECE",
  GAME_OVER = "GAME_OVER",
  REMATCH = "REMATCH",
  PING = "PING",

  // server -> client
  CONNECTED = "CONNECTED",
  ROOM_CREATED = "ROOM_CREATED",
  ROOM_JOINED = "ROOM_JOINED",
  PLAYER_JOINED = "PLAYER_JOINED",
  PLAYER_LEFT = "PLAYER_LEFT",
  START_MATCH = "START_MATCH",
  PLACE_ACCEPTED = "PLACE_ACCEPTED",
  PLACE_REJECTED = "PLACE_REJECTED",
  BOARD_UPDATE = "BOARD_UPDATE",
  SCORE_UPDATE = "SCORE_UPDATE",
  COMBO_UPDATE = "COMBO_UPDATE",
  OPPONENT_GAME_OVER = "OPPONENT_GAME_OVER",
  OPPONENT_DISCONNECTED = "OPPONENT_DISCONNECTED",
  OPPONENT_RECONNECTED = "OPPONENT_RECONNECTED",
  RECONNECT_STATE = "RECONNECT_STATE",
  TICK = "TICK",
  MATCH_END = "MATCH_END",
  REMATCH_STATUS = "REMATCH_STATUS",
  PONG = "PONG",
  ERROR = "ERROR",
}

export interface WireMessage {
  type: string;
  payload?: unknown;
}

// ---- client -> server payloads ----

export interface ConnectPayload {
  playerId: string;   // stable per-device identity
  name: string;       // display name
  token?: string;     // session token for reconnect (empty on first connect)
  matchId?: string;   // if set, attempt to rejoin this match
}

export interface JoinRoomPayload {
  roomCode: string;
}

export interface PlacePiecePayload {
  setIndex: number;    // which trio this piece belongs to
  slotIndex: number;   // 0..2 within the set
  cells: { r: number; c: number }[]; // absolute board cells the piece covers
}

export interface GameOverPayload {
  // Client declares it has no legal move. Server verifies against its
  // authoritative board before accepting.
}

// ---- server -> client payloads ----

export interface ConnectedPayload {
  playerId: string;
  token: string; // persist this; send it back on reconnect
  rejoined: boolean;
}

export interface RoomCreatedPayload {
  roomCode: string;
}

export interface RoomJoinedPayload {
  roomCode: string;
  players: PlayerSummary[];
}

export interface PlayerSummary {
  playerId: string;
  name: string;
  connected: boolean;
}

export interface StartMatchPayload {
  matchId: string;
  seed: number;
  startAtMs: number;   // server wall-clock time when play begins (after countdown)
  durationMs: number;  // match length
  serverNowMs: number; // server wall clock now, for offset estimation
  players: PlayerSummary[];
  opponent?: { score: number; board: number[] };
}

export interface PlaceAcceptedPayload {
  setIndex: number;
  slotIndex: number;
  gained: number;
  score: number;
  combo: number;
  linesCleared: number;
  clearedCells: { r: number; c: number }[];
  board: number[];      // 8 row bitmasks of the player's own board
  nextSetIndex: number; // authoritative set cursor
  gameOver: boolean;    // server says no moves remain
}

export interface BoardUpdatePayload {
  playerId: string;
  board: number[]; // 8 row bitmasks
  score: number;
  combo: number;
  linesClearedTotal: number;
  blocksPlacedTotal: number;
}

export interface MatchEndPayload {
  winnerId: string | null; // null = draw
  reason: "timer" | "both_game_over" | "disconnect" | "room_closed";
  players: {
    playerId: string;
    name: string;
    score: number;
    linesCleared: number;
    blocksPlaced: number;
    bestCombo: number;
    gameOver: boolean;
  }[];
}

export interface ReconnectStatePayload {
  matchId: string;
  seed: number;
  remainingMs: number;
  durationMs: number;
  startAtMs: number;
  serverNowMs: number;
  you: {
    score: number;
    combo: number;
    setIndex: number;
    usedSlots: number[];
    boardCells: number[]; // 64 ints
    gameOver: boolean;
  };
  opponent: {
    playerId: string;
    name: string;
    score: number;
    board: number[]; // bitmask rows
    gameOver: boolean;
    connected: boolean;
  };
  players: PlayerSummary[];
}

export interface TickPayload {
  remainingMs: number;
}

export interface ErrorPayload {
  code: string;
  message: string;
}

// ---- parsing / validation ----

const KNOWN_TYPES = new Set<string>(Object.values(Msg));
export const MAX_MESSAGE_BYTES = 16 * 1024;

export function parseMessage(raw: string): WireMessage | null {
  if (raw.length > MAX_MESSAGE_BYTES) return null;
  let obj: unknown;
  try {
    obj = JSON.parse(raw);
  } catch {
    return null;
  }
  if (typeof obj !== "object" || obj === null) return null;
  const m = obj as Record<string, unknown>;
  if (typeof m.type !== "string" || !KNOWN_TYPES.has(m.type)) return null;
  return { type: m.type, payload: m.payload };
}

export function asObject(v: unknown): Record<string, unknown> | null {
  return typeof v === "object" && v !== null ? (v as Record<string, unknown>) : null;
}

export function asString(v: unknown, maxLen = 64): string | null {
  return typeof v === "string" && v.length <= maxLen ? v : null;
}

export function asInt(v: unknown, min: number, max: number): number | null {
  return typeof v === "number" && Number.isInteger(v) && v >= min && v <= max ? v : null;
}

export function asCells(v: unknown, maxCells = 16): { r: number; c: number }[] | null {
  if (!Array.isArray(v) || v.length === 0 || v.length > maxCells) return null;
  const out: { r: number; c: number }[] = [];
  const seen = new Set<number>();
  for (const item of v) {
    const o = asObject(item);
    if (!o) return null;
    const r = asInt(o.r, 0, 7);
    const c = asInt(o.c, 0, 7);
    if (r === null || c === null) return null;
    const k = r * 8 + c;
    if (seen.has(k)) return null;
    seen.add(k);
    out.push({ r, c });
  }
  return out;
}
