class_name TrayView
extends HBoxContainer

## The bottom tray holding 3 piece slots. Slots are Panels that center their
## PieceView; match_screen reads slot rects for hit-testing and returns.

const SLOT_COUNT := 3

var slots: Array[PanelContainer] = []
var pieces: Array = []  # PieceView or null per slot
var slot_shapes: Array[int] = [-1, -1, -1]
var cell_px := 26.0

signal slot_pressed(slot: int, global_pos: Vector2)

func _ready() -> void:
	add_theme_constant_override("separation", 20)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS
	for i in SLOT_COUNT:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(200, 170)
		slot.add_theme_stylebox_override("panel", UITheme.panel_style(Color(1, 1, 1, 0.04), 18, Color.TRANSPARENT, 0, false))
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(center)
		slots.append(slot)
		pieces.append(null)
		add_child(slot)

func set_set(shape_indices: Array, used: Array) -> void:
	for i in SLOT_COUNT:
		slot_shapes[i] = shape_indices[i]
		if used[i]:
			clear_slot(i)
		else:
			_set_piece(i, shape_indices[i])

func set_slot_shape(slot: int, shape_index: int) -> void:
	slot_shapes[slot] = shape_index
	_set_piece(slot, shape_index)

func _set_piece(slot: int, shape_index: int) -> void:
	clear_slot(slot)
	var pv := PieceView.new()
	pv.set_shape(shape_index, cell_px)
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots[slot].get_child(0).add_child(pv)
	pieces[slot] = pv
	pv.modulate.a = 0.0
	pv.scale = Vector2(0.5, 0.5)
	pv.pivot_offset = pv.size * 0.5
	var tw := pv.create_tween().set_parallel(true)
	tw.tween_property(pv, "modulate:a", 1.0, 0.18)
	tw.tween_property(pv, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func clear_slot(slot: int) -> void:
	if pieces[slot]:
		pieces[slot].queue_free()
		pieces[slot] = null

func slot_available(slot: int) -> bool:
	return pieces[slot] != null

func slot_rect(slot: int) -> Rect2:
	return slots[slot].get_global_rect()

func slot_center(slot: int) -> Vector2:
	return slots[slot].get_global_rect().get_center()

func set_slot_enabled(slot: int, enabled: bool) -> void:
	if pieces[slot]:
		var pv: PieceView = pieces[slot]
		var tw := pv.create_tween()
		tw.tween_property(pv, "modulate:a", 1.0 if enabled else 0.3, 0.15)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_hit(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hit(event.position)

func _hit(local_pos: Vector2) -> void:
	for i in SLOT_COUNT:
		if pieces[i] and slots[i].get_rect().has_point(local_pos):
			slot_pressed.emit(i, get_global_transform() * local_pos)
			return
