# Building & installing the Android APK

## 1. Install requirements (on the Mac)

```bash
brew install --cask android-studio openjdk@17
```

- Open Android Studio → **SDK Manager** → install
  *Android SDK Platform 34+*, *Android SDK Build-Tools*, *Platform-Tools*.
- Note the SDK path (usually `~/Library/Android/sdk`).

## 2. Point Godot at the SDK

1. `brew install --cask godot` (or download from godotengine.org) — 4.3+.
2. Godot → **Editor → Editor Settings → Export → Android**:
   - **Android SDK Path** → `~/Library/Android/sdk`
   - **Debug Keystore** → generate one if needed:

   ```bash
   keytool -genkey -v -keystore ~/debug.keystore -alias androiddebugkey \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -storepass android -keypass android \
     -dname "CN=Android Debug,O=Android,C=US"
   ```

3. **Editor → Manage Export Templates → Download and Install** (match version).

## 3. Install the Android build template in the project

Open `client/` → **Project → Install Android Build Template** → Install.

## 4. Export the APK

**Project → Export…** → the **Android** preset (already configured in
`export_presets.cfg`: bundle id `com.blockduel.game`, `INTERNET` +
`VIBRATE` permissions, arm64) → **Export Project** → save as
`client/exports/block_duel.apk`.

Or via CLI:

```bash
godot --headless --path client --export-debug "Android" exports/block_duel.apk
```

## 5. Install on the Samsung

```bash
adb devices          # enable USB debugging on the phone first
adb install -r exports/block_duel.apk
```

…or copy the APK to the phone (Files/AirDrop-equivalent/USB) and open it —
allow "Install unknown apps" when prompted.

## 6. LAN multiplayer

- Phone and Mac on the **same Wi-Fi**.
- `SERVER_HOST` in `client/src/config/game_config.gd` = your Mac's LAN IP.
- No extra permissions needed — `INTERNET` covers LAN sockets.
- If it can't connect: check macOS firewall allows inbound on port 8080
  (System Settings → Network → Firewall → allow `node`), and that the Wi-Fi
  doesn't isolate clients ("AP isolation" on some routers breaks LAN play).

## Version bumps

`export_presets.cfg` → `version/code` (integer, must increase for updates)
and `version/name` (`0.1.0`).
