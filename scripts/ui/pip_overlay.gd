extends Control
## PiP(바탕화면 위젯) 모드의 오버레이.
## - 왼쪽 위: 골드 / 집중 타이머 (항상 표시, 반투명)
## - 오른쪽 위: 마우스를 올렸을 때만 나타나는 도구 모음 (집중, 크기, 투명도, 전체 화면)
## - 오른쪽 아래: 드래그해서 창 크기를 바꾸는 손잡이

signal exit_requested
signal window_changed

const GRIP := 18.0

var _info: Label
var _toolbar := HBoxContainer.new()
var _focus_button: Button
var _opacity_button: Button
var _resizing := false
var _resize_mouse_start := Vector2i.ZERO
var _resize_size_start := Vector2i.ZERO
var _hover := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _style(Color(0.1, 0.08, 0.12, 0.6)))
	chip.position = Vector2(6, 6)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info = TabBase.make_label("", 12, Color(1.0, 0.92, 0.6))
	_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	chip.add_child(_info)
	add_child(chip)

	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _style(Color(0.1, 0.08, 0.12, 0.85)))
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.position = Vector2(-6, 6)
	bar.add_child(_toolbar)
	_toolbar.add_theme_constant_override("separation", 2)
	_focus_button = _tool("집중", "30분 집중 시작 / 집중 끝내기", _toggle_focus)
	_tool("－", "창 작게", func(): _scale_window(1.0 / 1.2))
	_tool("＋", "창 크게", func(): _scale_window(1.2))
	_opacity_button = _tool("", "펫집 투명도", _cycle_opacity)
	_tool("전체", "전체 화면으로 돌아가기", func(): exit_requested.emit())
	add_child(bar)

	var win := get_window()
	win.mouse_entered.connect(func(): _hover = true)
	win.mouse_exited.connect(func(): _hover = false)
	_refresh()


func _style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(4)
	return sb


func _tool(text: String, tip: String, cb: Callable) -> Button:
	var b := TabBase.make_button(text, cb)
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 12)
	b.focus_mode = Control.FOCUS_NONE
	_toolbar.add_child(b)
	return b


func _process(_delta: float) -> void:
	if not visible:
		return
	_toolbar.get_parent().visible = _hover or _resizing
	if _resizing:
		var win := get_window()
		var s := _resize_size_start + (DisplayServer.mouse_get_position() - _resize_mouse_start)
		win.size = Vector2i(maxi(s.x, Settings.PIP_MIN_SIZE.x), maxi(s.y, Settings.PIP_MIN_SIZE.y))
	_refresh()
	queue_redraw()


func _refresh() -> void:
	var text := "%s G  +%s/분" % [Balance.format_number(Economy.gold), Balance.format_number(PetManager.total_production_per_min())]
	if FocusManager.active:
		var t := FocusManager.remaining_seconds() if FocusManager.target_min > 0 else FocusManager.elapsed_seconds()
		text += "\n집중 중 %s" % Balance.format_duration(t)
	_info.text = text
	_focus_button.text = "그만" if FocusManager.active else "집중"
	_opacity_button.text = "%d%%" % int(round(Settings.pip_opacity * 100))


func _toggle_focus() -> void:
	if FocusManager.active:
		FocusManager.stop_session()
	else:
		FocusManager.start_session(30)


func _scale_window(factor: float) -> void:
	var win := get_window()
	var s := Vector2(win.size) * factor
	win.size = Vector2i(maxi(int(s.x), Settings.PIP_MIN_SIZE.x), maxi(int(s.y), Settings.PIP_MIN_SIZE.y))
	window_changed.emit()


func _cycle_opacity() -> void:
	var steps := [1.0, 0.8, 0.6, 0.4]
	var idx := 0
	for i in steps.size():
		if absf(steps[i] - Settings.pip_opacity) < 0.05:
			idx = i
	Settings.pip_opacity = steps[(idx + 1) % steps.size()]
	window_changed.emit()


## 오른쪽 아래 손잡이로 창 크기 조절
func _grip_rect() -> Rect2:
	return Rect2(size - Vector2(GRIP, GRIP), Vector2(GRIP, GRIP))


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed and _grip_rect().has_point(mb.position):
			_resizing = true
			_resize_mouse_start = DisplayServer.mouse_get_position()
			_resize_size_start = get_window().size
			get_viewport().set_input_as_handled()
		elif not mb.pressed and _resizing:
			_resizing = false
			window_changed.emit()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	if not (_hover or _resizing):
		return
	var g := _grip_rect()
	for i in 3:
		var o := 4.0 + i * 5.0
		draw_line(g.end - Vector2(o, 2), g.end - Vector2(2, o), Color(1, 1, 1, 0.8), 2.0)
