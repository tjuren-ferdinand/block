import { config } from "../config";
import { Room } from "./room";

/** Tracks active rooms and generates unique human-readable room codes. */
export class RoomManager {
  private rooms = new Map<string, Room>();
  /** token -> { roomCode } for fast reconnect lookups */
  private tokenIndex = new Map<string, string>();

  createRoom(): Room | null {
    if (this.rooms.size >= config.maxRooms) return null;
    const code = this.generateCode();
    if (!code) return null;
    const room = new Room(code, (c) => this.disposeRoom(c));
    this.rooms.set(code, room);
    return room;
  }

  get(code: string): Room | undefined {
    return this.rooms.get(code.toUpperCase());
  }

  /** Find the room containing a session token (for reconnect). */
  findByToken(token: string): Room | undefined {
    const code = this.tokenIndex.get(token);
    if (!code) return undefined;
    return this.rooms.get(code);
  }

  indexToken(token: string, roomCode: string): void {
    this.tokenIndex.set(token, roomCode);
  }

  private disposeRoom(code: string): void {
    const room = this.rooms.get(code);
    if (room) {
      for (const p of room.players.values()) {
        this.tokenIndex.delete(p.session.token);
      }
    }
    room?.dispose();
    this.rooms.delete(code);
  }

  private generateCode(): string | null {
    for (let attempt = 0; attempt < 100; attempt++) {
      let code = "";
      for (let i = 0; i < config.roomCodeLength; i++) {
        code += Math.floor(Math.random() * 10).toString();
      }
      if (!this.rooms.has(code)) return code;
    }
    return null;
  }

  get roomCount(): number {
    return this.rooms.size;
  }
}
