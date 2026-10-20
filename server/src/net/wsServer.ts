/**
 * WebSocket layer: connection lifecycle, message validation/routing,
 * rate limiting, heartbeat, and session management.
 *
 * Protocol summary (JSON, {type, payload}):
 *   CONNECT        -> CONNECTED (issues session token)
 *   CREATE_ROOM    -> ROOM_CREATED / ERROR
 *   JOIN_ROOM      -> ROOM_JOINED + PLAYER_JOINED broadcast
 *   (2 players)    -> START_MATCH (seed, startAtMs, durationMs)
 *   PLACE_PIECE    -> PLACE_ACCEPTED / PLACE_REJECTED (+ BOARD_UPDATE to opp)
 *   GAME_OVER      -> verified; OPPONENT_GAME_OVER / MATCH_END
 *   REMATCH        -> REMATCH_STATUS; both accept -> new START_MATCH
 *   reconnect      -> CONNECT with token+matchId -> RECONNECT_STATE
 */

import { WebSocketServer, WebSocket } from "ws";
import { createServer, Server as HttpServer } from "http";
import { randomBytes } from "crypto";
import { config } from "../config";
import {
  asCells,
  asInt,
  asObject,
  asString,
  Msg,
  parseMessage,
  WireMessage,
} from "../protocol";
import { Cell } from "../game/shapes";
import { RateLimiter } from "../util/rateLimiter";
import { RoomManager } from "../rooms/roomManager";
import { Room, SessionHandle } from "../rooms/room";

interface ClientCtx {
  socket: WebSocket;
  limiter: RateLimiter;
  playerId: string;
  name: string;
  token: string;
  room: Room | null;
  isAlive: boolean;
  lastMessage: string;
}

export class GameServer {
  private wss: WebSocketServer;
  private http: HttpServer;
  private rooms = new RoomManager();
  private clients = new Set<ClientCtx>();
  private heartbeat: NodeJS.Timeout;

  constructor(port = config.port, host = config.host) {
    // Plain HTTP fallback: /health for uptime checks, everything else 426.
    this.http = createServer((req, res) => {
      if (req.url === "/health" || req.url === "/") {
        res.writeHead(200, { "content-type": "application/json" });
        res.end(JSON.stringify({ status: "ok", service: "block-duel-server" }));
      } else {
        res.writeHead(404);
        res.end();
      }
    });
    this.wss = new WebSocketServer({ server: this.http });
    this.wss.on("connection", (socket) => this.onConnection(socket));
    this.http.listen(port, host);
    this.heartbeat = setInterval(() => this.heartbeatSweep(), config.heartbeatIntervalMs);
  }

  close(): void {
    clearInterval(this.heartbeat);
    for (const c of this.clients) c.socket.terminate();
    this.wss.close();
    this.http.close();
  }

  // ---------------------------------------------------------

  private onConnection(socket: WebSocket): void {
    const ctx: ClientCtx = {
      socket,
      limiter: new RateLimiter(config.rateLimitCapacity, config.rateLimitPerSec),
      playerId: "",
      name: "",
      token: "",
      room: null,
      isAlive: true,
      lastMessage: "",
    };
    this.clients.add(ctx);

    socket.on("pong", () => {
      ctx.isAlive = true;
    });
    socket.on("message", (data) => this.onMessage(ctx, data.toString()));
    socket.on("close", () => this.onClose(ctx));
    socket.on("error", () => this.onClose(ctx));
  }

  private heartbeatSweep(): void {
    for (const ctx of this.clients) {
      if (!ctx.isAlive) {
        ctx.socket.terminate();
        continue;
      }
      ctx.isAlive = false;
      try {
        ctx.socket.ping();
      } catch {
        /* socket already gone */
      }
    }
  }

  private onMessage(ctx: ClientCtx, raw: string): void {
    if (!ctx.limiter.allow()) {
      this.send(ctx, Msg.ERROR, { code: "rate_limited", message: "Slow down" });
      return;
    }
    const msg = parseMessage(raw);
    if (!msg) {
      this.send(ctx, Msg.ERROR, { code: "bad_message", message: "Malformed message" });
      return;
    }
    ctx.lastMessage = msg.type;

    // Every message except CONNECT requires a session.
    if (msg.type !== Msg.CONNECT && !ctx.playerId) {
      this.send(ctx, Msg.ERROR, { code: "not_connected", message: "Send CONNECT first" });
      return;
    }

    switch (msg.type) {
      case Msg.CONNECT: this.handleConnect(ctx, msg); break;
      case Msg.CREATE_ROOM: this.handleCreateRoom(ctx); break;
      case Msg.JOIN_ROOM: this.handleJoinRoom(ctx, msg); break;
      case Msg.LEAVE_ROOM: this.handleLeaveRoom(ctx); break;
      case Msg.PLACE_PIECE: this.handlePlace(ctx, msg); break;
      case Msg.GAME_OVER: ctx.room?.handleGameOverClaim(ctx.playerId); break;
      case Msg.REMATCH: ctx.room?.handleRematch(ctx.playerId); break;
      case Msg.PING: this.send(ctx, Msg.PONG, { t: Date.now() }); break;
      default:
        this.send(ctx, Msg.ERROR, { code: "unhandled", message: `Unhandled type ${msg.type}` });
    }
  }

  private handleConnect(ctx: ClientCtx, msg: WireMessage): void {
    const p = asObject(msg.payload);
    const playerId = p ? asString(p.playerId, 64) : null;
    const name = p ? asString(p.name, config.maxNameLength) : null;
    if (!playerId || !name) {
      this.send(ctx, Msg.ERROR, { code: "bad_connect", message: "playerId and name required" });
      return;
    }
    ctx.playerId = playerId;
    ctx.name = name;

    const token = p?.token ? asString(p.token, 128) : null;
    const matchId = p?.matchId ? asString(p.matchId, 64) : null;

    // Reconnection path: token belongs to a live room slot.
    if (token && matchId) {
      const room = this.rooms.findByToken(token);
      const slot = room?.getPlayerByToken(token);
      if (room && slot && room.matchId === matchId) {
        ctx.token = token;
        const session = this.makeSession(ctx);
        if (room.attachSession(session)) {
          ctx.room = room;
          this.send(ctx, Msg.CONNECTED, { playerId, token, rejoined: true });
          const state = room.buildReconnectState(playerId);
          if (state) {
            this.send(ctx, Msg.RECONNECT_STATE, state);
          } else {
            this.send(ctx, Msg.ROOM_JOINED, { roomCode: room.code, players: room.playerSummaries() });
          }
          return;
        }
      }
      // fall through to fresh session
    }

    ctx.token = randomBytes(16).toString("hex");
    this.send(ctx, Msg.CONNECTED, { playerId, token: ctx.token, rejoined: false });
  }

  private handleCreateRoom(ctx: ClientCtx): void {
    if (ctx.room) {
      this.send(ctx, Msg.ERROR, { code: "in_room", message: "Already in a room" });
      return;
    }
    const room = this.rooms.createRoom();
    if (!room) {
      this.send(ctx, Msg.ERROR, { code: "server_full", message: "Too many rooms, try later" });
      return;
    }
    const session = this.makeSession(ctx);
    const res = room.addPlayer(session);
    if (!res.ok) {
      this.send(ctx, Msg.ERROR, { code: "join_failed", message: res.error ?? "Failed" });
      return;
    }
    ctx.room = room;
    this.rooms.indexToken(ctx.token, room.code);
    this.send(ctx, Msg.ROOM_CREATED, { roomCode: room.code });
  }

  private handleJoinRoom(ctx: ClientCtx, msg: WireMessage): void {
    if (ctx.room) {
      this.send(ctx, Msg.ERROR, { code: "in_room", message: "Already in a room" });
      return;
    }
    const p = asObject(msg.payload);
    const code = p ? asString(p.roomCode, 8) : null;
    if (!code || !/^\d{6}$/.test(code)) {
      this.send(ctx, Msg.ERROR, { code: "bad_code", message: "Room code must be 6 digits" });
      return;
    }
    const room = this.rooms.get(code);
    if (!room) {
      this.send(ctx, Msg.ERROR, { code: "room_not_found", message: "No room with that code" });
      return;
    }
    const session = this.makeSession(ctx);
    const res = room.addPlayer(session);
    if (!res.ok) {
      this.send(ctx, Msg.ERROR, { code: "join_failed", message: res.error ?? "Could not join" });
      return;
    }
    ctx.room = room;
    this.rooms.indexToken(ctx.token, room.code);
    this.send(ctx, Msg.ROOM_JOINED, { roomCode: room.code, players: room.playerSummaries() });
  }

  private handleLeaveRoom(ctx: ClientCtx): void {
    if (!ctx.room) return;
    const room = ctx.room;
    ctx.room = null;
    room.removePlayer(ctx.playerId);
  }

  private handlePlace(ctx: ClientCtx, msg: WireMessage): void {
    if (!ctx.room) {
      this.send(ctx, Msg.PLACE_REJECTED, { code: "no_room", message: "Not in a match" });
      return;
    }
    const p = asObject(msg.payload);
    if (!p) {
      this.send(ctx, Msg.PLACE_REJECTED, { code: "bad_payload", message: "Missing payload" });
      return;
    }
    const setIndex = asInt(p.setIndex, 0, 100000);
    const slotIndex = asInt(p.slotIndex, 0, 2);
    const rawCells = asCells(p.cells);
    if (setIndex === null || slotIndex === null || !rawCells) {
      this.send(ctx, Msg.PLACE_REJECTED, { code: "bad_payload", message: "Invalid placement fields" });
      return;
    }
    const cells: Cell[] = rawCells.map((cell) => [cell.r, cell.c] as const);
    ctx.room.handlePlace(ctx.playerId, setIndex, slotIndex, cells);
  }

  private onClose(ctx: ClientCtx): void {
    if (!this.clients.has(ctx)) return;
    this.clients.delete(ctx);
    if (ctx.room) {
      ctx.room.handleDisconnect(ctx.playerId);
    }
  }

  private makeSession(ctx: ClientCtx): SessionHandle {
    return {
      playerId: ctx.playerId,
      name: ctx.name,
      token: ctx.token,
      connected: true,
      send: (type, payload) => this.send(ctx, type, payload),
    };
  }

  private send(ctx: ClientCtx, type: Msg, payload: unknown): void {
    if (ctx.socket.readyState !== WebSocket.OPEN) return;
    try {
      ctx.socket.send(JSON.stringify({ type, payload }));
    } catch {
      /* dropped */
    }
  }
}
