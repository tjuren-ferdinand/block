# Web / Live Deploy Guide

Two ways to play BLOCK DUEL on phones — instant tunnel test, or a permanent
cloud deploy.

---

## A. Instant test — Cloudflare quick tunnels (no accounts needed)

Exposes the game + server running on your PC to the public internet.
Works on any network — phones don't even need your Wi-Fi.

Requires `cloudflared` — download the binary for your OS from
https://github.com/cloudflare/cloudflared/releases (no account needed).

```bash
# 1. WebSocket server
cd server && npm install && npm start        # port 8080

# 2. Tunnel it (note the https://xxx.trycloudflare.com URL)
tools/cloudflared tunnel --url http://localhost:8080

# 3. Point the client at that URL, then rebuild the web export
#    client/src/config/game_config.gd:
#      SERVER_HOST = "xxx.trycloudflare.com"  (no https://)
#      SERVER_PORT = 443
#      USE_SSL     = true

# 4. Export the web build (Godot 4.3+ with web export templates)
godot --headless --path client --export-release "Web" exports/web/index.html

# 5. Serve it (sets the COOP/COEP headers Godot web requires)
node scripts/web_server.mjs 8081 client/exports/web

# 6. Tunnel that too
tools/cloudflared tunnel --url http://localhost:8081
#    → https://yyy.trycloudflare.com  ← open this on both phones
```

On each phone: open the second URL in Safari/Chrome → MULTIPLAYER →
CREATE MATCH on one, JOIN MATCH + room code on the other.

> Quick tunnels die when you close cloudflared and get random names each
> run. Fine for testing, not for shipping.

---

## B. Permanent deploy — Vercel (client) + Render (server)

**Vercel cannot host the WebSocket server** (serverless functions don't
support long-lived WS). Split it: static web build on Vercel, WS server on
Render (free tier supports WebSockets).

### Server → Render (one-time, ~2 min)

1. Push this repo to GitHub (done).
2. https://render.com → sign in with GitHub → **New → Blueprint** → pick the
   repo. `render.yaml` auto-configures everything.
3. Note your URL: `https://block-duel-server.onrender.com`
   (free tier sleeps after ~15 min idle — first connect takes ~30 s to wake)

### Client → Vercel

1. In Godot: export the Web build (preset "Web") into `client/exports/web/`
   with `SERVER_HOST` set to your Render host, `SERVER_PORT = 443`,
   `USE_SSL = true`. Commit and push (or upload the folder).
2. https://vercel.com → **Add New → Project** → import the repo.
   `vercel.json` already sets output dir + the required isolation headers.
3. Share the `*.vercel.app` URL — the game runs in any mobile browser.

### Runtime override

Web builds accept `?server=wss://host` in the page URL, so one build can be
pointed at different backends without re-exporting:

```
https://your-game.vercel.app/?server=wss://block-duel-server.onrender.com
```

---

## Notes for phone browsers

- iOS Safari 15+/Chrome on Android both run Godot 4 web exports.
- First load downloads ~40 MB (WASM) — use Wi-Fi for the first open.
- "Add to Home Screen" gives a fullscreen app-like experience.
- Audio unlocks on first tap (browser autoplay policy).
