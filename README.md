# BLOCK DUEL

An original realtime 1v1 block-puzzle duel game. Drag pieces onto an 8×8
board, clear rows and columns, build combos — and race a live opponent
solving the *same* piece sequence.

- **Client:** Godot 4.3+ (GDScript, 2D, portrait, iOS + Android)
- **Server:** Node.js + TypeScript WebSocket server (authoritative, LAN-ready)
- **No paid services.** Runs entirely on your LAN for development.

```
/client    Godot project (game client)
/server    Node + TypeScript multiplayer server
/docs      Protocol, Android, iOS, architecture docs
/scripts   Dev helpers
```

---

## 1. Prerequisites

**On your Mac:**

- [Godot 4.3+ (standard build)](https://godotengine.org/download) — required to open the project and export.
- Node.js 18+ (`brew install node`)
- Xcode (for iOS builds)
- Android Studio / Android SDK + OpenJDK 17 (for Android builds)

## 2. Start the multiplayer server

```bash
cd server
npm install
npm run dev        # tsx watch — reloads on edits
# or: npm start    (single run)
```

It prints something like:

```
Block Duel server running
Port: 8080
Local network IP: 192.168.1.50  ->  ws://192.168.1.50:8080
```

**Note your LAN IP — you will paste it into the client config next.**

## 3. Point the client at your server

Open **`client/src/config/game_config.gd`** and set:

```gdscript
const SERVER_HOST := "192.168.1.50"   # your Mac's IP from step 2
const SERVER_PORT := 8080
const USE_SSL := false                 # true only when using wss:// in production
```

This is also where you rename the game: `const GAME_NAME := "BLOCK DUEL"`.

## 4. Open / run the Godot project

```bash
# Open the project in the editor (first open builds the import cache)
godot --path client
# or run it directly:
godot --path client
```

Then press **F5** (or `godot --path client` from the CLI) to play on desktop —
touch controls work with the mouse.

## 5. Run tests

```bash
# Server unit + integration tests (rules, RNG, rooms, full match flow)
cd server && npm test

# Client logic tests (headless; golden vectors shared with the server)
godot --headless --path client --import        # once
godot --headless --path client -s res://tests/run_tests.gd

# Full app smoke test (solo match, screen flow)
godot --path client -- --smoke

# Live client<->server round-trip test (server must be running)
godot --path client -- --net-smoke
```

---

## 5b. Play on phones right now (web build, no app install)

The fastest way to test multiplayer on real phones — no Xcode/Android SDK
needed. The game runs in the phone's browser:

```bash
node scripts/web_server.mjs 8081 client/exports/web   # serves the web export
tools/cloudflared tunnel --url http://localhost:8081  # public URL for phones
tools/cloudflared tunnel --url http://localhost:8080  # public URL for the WS server
```

Full instructions (including a permanent Vercel + Render deploy):
**docs/DEPLOY_WEB.md**

## 6. Play an iPhone-vs-Samsung LAN match

1. Start the server on your Mac (step 2). All three devices must be on the
   **same Wi-Fi network**.
2. Set `SERVER_HOST` in `game_config.gd` to your Mac's LAN IP and rebuild both apps.
3. On the **iPhone**: MULTIPLAYER → CREATE MATCH → note the 6-digit **ROOM CODE**.
4. On the **Samsung**: MULTIPLAYER → JOIN MATCH → type the code.
5. Both screens show **3 · 2 · 1 · GO** and then identical piece sets. Higher
   score when the 3:00 timer ends wins.

---

## 7. Android export (Samsung)

See **docs/ANDROID.md** for the complete guide. Quick version:

1. In Godot: **Editor → Editor Settings → Export → Android** — set the Android
   SDK path (from Android Studio) and `debug` keystore
   (`keytool -genkey -v -keystore debug.keystore -alias androiddebugkey
   -keyalg RSA -keysize 2048 -validity 10000`).
2. **Project → Install Android Build Template**.
3. **Project → Export → Android (preset "Android")** → Export Project →
   produces `client/exports/block_duel.apk`.
4. Install on the Samsung: `adb install exports/block_duel.apk`
   (or copy the APK to the phone and open it).
5. The preset already includes `INTERNET` and `VIBRATE` permissions — LAN
   multiplayer works out of the box.

## 8. iOS export (iPhone)

See **docs/IOS.md** for the complete guide. Quick version:

1. **Project → Export → iOS (preset "iOS")** → Export Project → generates an
   Xcode project in `client/exports/block_duel_ios/`.
2. Open `block_duel_ios.xcodeproj` in **Xcode**.
3. Select the app target → **Signing & Capabilities** → choose your
   **Development Team** (free Apple ID works) and set a unique
   **Bundle Identifier**.
4. On the iPhone: **Settings → Privacy & Security → Developer Mode → ON**
   (requires a restart).
5. Select your iPhone in Xcode and press **Run**.
6. The preset already declares `NSLocalNetworkUsageDescription`
   ("uses your local network to find and play matches") so iOS will allow
   WebSocket connections to your Mac over LAN. Accept the prompt on first launch.

---

## Architecture in one paragraph

Both the client (GDScript) and server (TypeScript) share an identical
deterministic rulebook: the same shape catalog, the same mulberry32 RNG,
the same weighted piece generator, the same board/scoring logic — verified by
golden-vector tests on both sides. The server is authoritative: clients send
*placements* (`{setIndex, slotIndex, cells}`), the server derives the board,
score and combo itself, and relays compact board bitmasks to the opponent.
Sessions survive ~10 s of Wi-Fi drop via token-based reconnect. See
**docs/PROTOCOL.md** and **docs/ARCHITECTURE.md**.
