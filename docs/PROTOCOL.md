# Block Duel — Wire Protocol

JSON over WebSocket: `{ "type": "<TYPE>", "payload": { ... } }`

Server definitions: `server/src/protocol.ts`
Client mirror: `client/src/net/protocol.gd`

## Session

### CONNECT → CONNECTED
```json
{"type":"CONNECT","payload":{"playerId":"guest-abc123","name":"Player 4827",
 "token":"<optional session token>","matchId":"<optional, to rejoin>"}}
→ {"playerId":"guest-abc123","token":"<hex>","rejoined":false}
```
`token` identifies the *connection slot*, not the player. Persist it; on
reconnect send `token` + `matchId` to rejoin a live match → server replies
`rejoined:true` + `RECONNECT_STATE`.

### PING → PONG
Client pings every ~2s; server echoes `{t: serverNowMs}`.

## Rooms

| Message | Direction | Payload |
|---|---|---|
| `CREATE_ROOM` | c→s | `{}` |
| `ROOM_CREATED` | s→c | `{roomCode:"482913"}` |
| `JOIN_ROOM` | c→s | `{roomCode:"482913"}` |
| `ROOM_JOINED` | s→c | `{roomCode, players:[{playerId,name,connected}]}` |
| `PLAYER_JOINED` | s→c (broadcast) | `{players:[...]}` |
| `PLAYER_LEFT` | s→c | `{playerId, players}` |
| `LEAVE_ROOM` | c→s | `{}` |

When the 2nd player joins, the server immediately starts a match.

## Match lifecycle

### START_MATCH (s→c, broadcast)
```json
{"matchId":"482913-1-lx3","seed":2926569286,"startAtMs":1700000003200,
 "durationMs":180000,"serverNowMs":1700000000000,"players":[...]}
```
Clients compute `clockOffset = serverNowMs − localMs` and show a synced
3-2-1-GO that ends at `startAtMs`.

### PLACE_PIECE (c→s)
```json
{"setIndex":0,"slotIndex":1,"cells":[{"r":3,"c":2},{"r":3,"c":3},...]}
```
`cells` = absolute board cells the piece covers. The server re-derives the
piece from `(seed, setIndex, slotIndex)`, verifies the cell set matches the
shape, verifies the placement is legal on its authoritative board, applies
line clears and computes the score itself.

### PLACE_ACCEPTED (s→c, to placer)
`{setIndex, slotIndex, gained, score, combo, linesCleared, clearedCells[],
 board(bitmask), nextSetIndex, gameOver}`

### PLACE_REJECTED (s→c, to placer)
`{code, message}` followed by a corrective `BOARD_UPDATE` for the placer.

### BOARD_UPDATE (s→c)
Sent to the **opponent** after each placement, and to the placer as a
correction on rejection. Compact: `board` is 8 row bitmasks.
`{playerId, board:[8 bitmasks], score, combo, linesClearedTotal, blocksPlacedTotal}`

### SCORE_UPDATE / COMBO_UPDATE
Redundant fast-path messages `{score,combo,gained}` / `{combo}` — the client
primarily consumes `PLACE_ACCEPTED` + `BOARD_UPDATE`.

### TICK (s→c, 1/s)
`{remainingMs}` — authoritative clock sync.

### GAME_OVER (c→s)
Client claims no legal move. Server verifies against its authoritative board;
if any placement exists it replies `ERROR {code:"not_game_over"}`.
A verified game over locks the player's score; opponent keeps playing.
Broadcast to opponent: `OPPONENT_GAME_OVER {playerId, score}`.

### MATCH_END (s→c)
`{winnerId|null, reason:"timer"|"both_game_over"|"disconnect"|"room_closed",
 players:[{playerId,name,score,linesCleared,blocksPlaced,bestCombo,gameOver}]}`

## Reconnection

- Socket drop while in a match → server marks player disconnected, sends
  `OPPONENT_DISCONNECTED {playerId, graceMs}` to the other side, and starts a
  **10 s grace timer**.
- Client reconnects with `CONNECT {token, matchId}` → `CONNECTED{rejoined:true}`
  + `RECONNECT_STATE` (full resync: own board cells, score, set cursor, used
  slots, opponent board bitmask + score, remaining time).
- `OPPONENT_RECONNECTED {playerId}` is broadcast to the opponent.
- Grace expiry → `MATCH_END {reason:"disconnect"}` — the connected player wins.

## Rematch

`REMATCH` (c→s) marks acceptance → `REMATCH_STATUS {requestedBy, waitingFor,
 accepted[]}` broadcast; when both accept, a fresh `START_MATCH` with a new
 seed is sent.

## Errors & abuse

- `ERROR {code, message}` — malformed JSON, bad types, unknown room, rate
  limiting (`rate_limited`), etc.
- Limits: 16 KB max message, ~20 msg/s token bucket, 500 rooms max, ws
  heartbeat (15 s ping / 45 s kill).

## Security model (foundation, not production-grade)

- The server owns: match seed, piece sequence, board states, scores, timer,
  winner. Clients never send a score — only placements.
- The client optimistically renders its own placements (it runs identical
  rules); on `PLACE_REJECTED`/`BOARD_UPDATE` it resyncs to server truth.
- Hardening later: sign CONNECT payloads, server-side action rate validation,
  full board-hash checkpoints.
