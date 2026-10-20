class_name Haptics
extends RefCounted

## Thin wrapper around device vibration gated by the user's setting.

static func light() -> void:
	_buzz(12)

static func medium() -> void:
	_buzz(28)

static func heavy() -> void:
	_buzz(50)

static func _buzz(ms: int) -> void:
	if not Settings.haptics_enabled:
		return
	Input.vibrate_handheld(ms)
