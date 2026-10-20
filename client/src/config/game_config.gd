class_name GameConfig
extends RefCounted

## Central configuration. THE ONE FILE TO EDIT for branding + server target.

# ---- Branding ----
const GAME_NAME := "BLOCK DUEL"
const GAME_VERSION := "0.1.0"

# ---- Networking ----
# For LAN play: set SERVER_HOST to your Mac's local IP (printed by the server
# on startup, e.g. 192.168.1.50). For production use a domain + USE_SSL=true.
const SERVER_HOST := "delayed-little-identifier-fred.trycloudflare.com"
const SERVER_PORT := 443
const USE_SSL := true

static func server_url() -> String:
	var override := _url_override()
	if override != "":
		return override
	var scheme := "wss" if USE_SSL else "ws"
	return "%s://%s:%d" % [scheme, SERVER_HOST, SERVER_PORT]

## Web builds may carry ?server=wss://host in the page URL to override the
## baked-in server target (handy for testing deployments without re-export).
static func _url_override() -> String:
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval(
			"new URLSearchParams(window.location.search).get('server') || ''")
		return str(q)
	return ""

# ---- Board ----
const BOARD_SIZE := 8
const PIECES_PER_SET := 3

# ---- Feel ----
const DRAG_LIFT_PX := 120.0          # how far above the finger the piece floats
const DRAG_SCALE := 1.12             # pickup scale
const PREVIEW_ALPHA := 0.45
const SNAP_TWEEN_TIME := 0.08
const RETURN_TWEEN_TIME := 0.18
const CLEAR_ANIM_TIME := 0.28

# ---- Palette (original visual identity) ----
const COLOR_BG_TOP := Color("171a3a")
const COLOR_BG_BOTTOM := Color("0d0f24")
const COLOR_BOARD := Color("1d2148")
const COLOR_CELL := Color("252a5c")
const COLOR_CELL_EDGE := Color("1a1d42")
const COLOR_VALID := Color("4de3c2")
const COLOR_INVALID := Color("ff5a6e")
const COLOR_TEXT := Color("f2f4ff")
const COLOR_TEXT_DIM := Color("8f96c9")
const COLOR_ACCENT := Color("7c6cff")
const COLOR_ACCENT_2 := Color("ffb84d")
const COLOR_GOLD := Color("ffd76a")

# Per-shape-index palette (cycled). Saturated candy colors.
const PIECE_COLORS: Array[Color] = [
	Color("7c6cff"), # violet
	Color("4de3c2"), # mint
	Color("ffb84d"), # amber
	Color("ff6f91"), # rose
	Color("5db8ff"), # sky
	Color("b8ef5a"), # lime
	Color("ff8e3d"), # orange
]

static func piece_color(shape_index: int) -> Color:
	return PIECE_COLORS[shape_index % PIECE_COLORS.size()]
