extends Control
## 펫집을 담는 프레임. 창 크기와 상관없이 열린 공간 전체가 항상 화면 안에 들어오도록 자동으로 맞춘다.
## - 마우스 휠: 확대/축소 (커서 기준)
## - 빈 곳 드래그: 이동 (PiP 모드에서는 창 자체를 옮긴다)
## - 더블클릭: 화면 맞춤으로 되돌리기

signal window_drag_finished

const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.0
const SKY_DAY := Color(0.75, 0.88, 1.0)
const SKY_NIGHT := Color(0.1, 0.12, 0.28)

var house_view: Control
var pip_mode := false:
	set(v):
		pip_mode = v
		reset_view()
		queue_redraw()

var zoom := 1.0
var pan := Vector2.ZERO

var _panning := false
var _window_drag := false
var _drag_mouse_start := Vector2i.ZERO
var _drag_window_start := Vector2i.ZERO


func setup(view: Control) -> void:
	house_view = view
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(view)
	resized.connect(_layout)
	EventBus.house_level_changed.connect(func(_l): reset_view())


func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	_layout()


func _process(_delta: float) -> void:
	_layout()
	if _window_drag:
		var win := get_window()
		win.position = _drag_window_start + (DisplayServer.mouse_get_position() - _drag_mouse_start)


func _fit_scale() -> float:
	var content: Rect2 = house_view.content_rect()
	return minf(size.x / content.size.x, size.y / content.size.y)


func _base_position(s: float) -> Vector2:
	var content: Rect2 = house_view.content_rect()
	return (size - content.size * s) * 0.5 - content.position * s


func _layout() -> void:
	if house_view == null or size.x <= 1.0 or size.y <= 1.0:
		return
	var s := _fit_scale() * zoom
	var content: Rect2 = house_view.content_rect()
	# 확대했을 때 내용이 화면 밖으로 완전히 빠져나가지 않게 제한
	var slack := (content.size * s - size) * 0.5
	pan.x = clampf(pan.x, -maxf(0.0, slack.x), maxf(0.0, slack.x))
	pan.y = clampf(pan.y, -maxf(0.0, slack.y), maxf(0.0, slack.y))
	house_view.scale = Vector2(s, s)
	house_view.position = _base_position(s) + pan


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_at(mb.position, 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.double_click:
				reset_view()
			elif mb.pressed and pip_mode:
				_window_drag = true
				_drag_mouse_start = DisplayServer.mouse_get_position()
				_drag_window_start = get_window().position
			elif not mb.pressed and _window_drag:
				_window_drag = false
				window_drag_finished.emit()
			else:
				_panning = mb.pressed and not pip_mode
			accept_event()
	elif event is InputEventMouseMotion and _panning:
		pan += (event as InputEventMouseMotion).relative
		_layout()
		accept_event()


func _zoom_at(point: Vector2, factor: float) -> void:
	var old_s := _fit_scale() * zoom
	var world := (point - house_view.position) / old_s
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var new_s := _fit_scale() * zoom
	pan = point - world * new_s - _base_position(new_s)
	_layout()


func _draw() -> void:
	if not pip_mode:
		draw_rect(Rect2(Vector2.ZERO, size), SKY_NIGHT if Clock.is_night() else SKY_DAY)
