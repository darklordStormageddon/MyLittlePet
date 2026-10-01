class_name TabBase
extends ScrollContainer
## 사이드 패널 탭의 공통 기반. 코드로 UI를 구성하고 주기적으로 refresh() 한다.

var box := VBoxContainer.new()


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	add_child(box)


## 매 0.5초마다 호출 (보이는 탭만)
func refresh() -> void:
	pass


func clear(container: Container) -> void:
	for c in container.get_children():
		container.remove_child(c)
		c.queue_free()


static func make_label(text: String, font_size: int = 14, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l


static func make_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	return b


static func make_card() -> Array:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.06)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	return [panel, v]


func add_title(text: String) -> Label:
	var l := make_label(text, 18, Color(1.0, 0.85, 0.55))
	box.add_child(l)
	return l


func add_text(text: String, font_size: int = 14) -> Label:
	var l := make_label(text, font_size)
	box.add_child(l)
	return l
