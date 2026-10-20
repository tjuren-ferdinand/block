# Building & installing on iPhone (via Xcode)

## 1. Requirements

- macOS + **Xcode 15+**
- **Godot 4.3+** with matching export templates
  (**Editor → Manage Export Templates → Download and Install**)
- An Apple ID (free works for personal devices)

## 2. Export the Xcode project

Open `client/` in Godot → **Project → Export…** → **iOS** preset →
**Export Project** → choose/create `client/exports/block_duel_ios/`.
Godot generates an Xcode project (`block_duel_ios.xcodeproj`).

The preset already sets:

- Bundle identifier: `com.blockduel.game` (change to your own reverse-DNS id)
- `NSLocalNetworkUsageDescription` — required for LAN multiplayer on iOS 14+.
  If your Godot version doesn't map the preset key, add it manually in Xcode:
  **Info tab → Custom iOS Target Properties → +** →
  `Privacy - Local Network Usage Description` =
  `"BLOCK DUEL uses your local network to find and play matches with nearby devices."`
- arm64, portrait, game category.

## 3. Signing

1. Open `exports/block_duel_ios/block_duel_ios.xcodeproj` in Xcode.
2. Select the project → target → **Signing & Capabilities**.
3. Enable **Automatically manage signing**, pick your **Team**
   (Xcode → Settings → Accounts → add your Apple ID if needed).
4. If the bundle id is taken on your account, change it (e.g.
   `com.yourname.blockduel`).

## 4. Enable Developer Mode on the iPhone

**Settings → Privacy & Security → Developer Mode → ON** → restart → confirm.
(The toggle appears only after the phone has been connected to Xcode once.)

## 5. Build & run

- Plug the iPhone in (or use Wi-Fi after first pairing), select it as the
  run destination, press **▶ Run**.
- First launch on the device may require
  **Settings → General → VPN & Device Management → trust your developer cert**.

## 6. LAN multiplayer on iOS

- iPhone + Mac on the **same Wi-Fi**.
- `SERVER_HOST` in `client/src/config/game_config.gd` = your Mac's LAN IP.
- On first launch, iOS asks **"BLOCK DUEL would like to find and connect to
  devices on your local network"** → tap **OK** (that's the
  `NSLocalNetworkUsageDescription` prompt). If denied, WebSocket connections
  to the Mac will fail — re-enable in Settings → Privacy → Local Network.
- macOS firewall must allow inbound connections to `node` on port 8080.

## Notes

- WebSocket TLS (`wss://`) works without App Transport Security exceptions;
  plain `ws://` to a LAN IP is allowed for local networking in dev builds.
  If you hit ATS issues over plain ws to an IP, keep using the LAN IP (no
  domain) — local IPs are exempt.
