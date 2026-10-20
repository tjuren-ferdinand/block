/** Server configuration. All values can be overridden via environment. */

export const config = {
  port: Number(process.env.PORT ?? 8080),
  host: process.env.HOST ?? "0.0.0.0",

  matchDurationMs: Number(process.env.MATCH_DURATION_MS ?? 180_000), // 3 minutes
  countdownMs: Number(process.env.COUNTDOWN_MS ?? 3_200),            // 3-2-1-GO

  reconnectGraceMs: Number(process.env.RECONNECT_GRACE_MS ?? 10_000),
  tickIntervalMs: 1_000,

  maxRooms: 500,
  roomCodeLength: 6,
  maxPlayersPerRoom: 2,

  // rate limiting: token bucket per connection
  rateLimitCapacity: 30,
  rateLimitPerSec: 20,

  heartbeatIntervalMs: 15_000,
  heartbeatTimeoutMs: 45_000,

  maxNameLength: 24,
} as const;
